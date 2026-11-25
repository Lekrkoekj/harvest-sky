Shader "Vivify/Rock"
{
    Properties
    {
        _Color ("Color Day", Color) = (1, 1, 1, 1)
        _ColorNight ("Color Night", Color) = (1, 1, 1, 1)
        _DayNightCycle ("Day/Night Cycle", Range(0, 1)) = 1
        _Tex ("Texture", 2D) = "white" {}
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 2)) = 1
        _MaskMap ("Mask Map (G = AO)", 2D) = "white" {}
        _AOStrength ("AO Strength", Range(0, 1)) = 1
        _Glow ("Glow", Range(0, 1)) = 0
        _Ambient ("Ambient Lighting", Range(0, 1)) = 0.02

        [Header(Water Line)]
        _WaterHeight ("Water Height", Float) = 0
        _WetHeight ("Wet Band Height", Float) = 0.4
        _WetDarken ("Wet Darkening", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 tSpace0 : TEXCOORD2;
                float3 tSpace1 : TEXCOORD3;
                float3 tSpace2 : TEXCOORD4;
                SHADOW_COORDS(5)
                UNITY_FOG_COORDS(6)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _Color;
            float4 _ColorNight;
            float _DayNightCycle;
            sampler2D _Tex;
            float4 _Tex_ST;
            sampler2D _NormalMap;
            float _NormalStrength;
            sampler2D _MaskMap;
            float _AOStrength;
            float _Glow;
            float _Ambient;
            float _WaterHeight;
            float _WetHeight;
            float _WetDarken;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Tex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                float3 n = UnityObjectToWorldNormal(v.normal);
                float3 t = UnityObjectToWorldDir(v.tangent.xyz);
                float3 b = cross(n, t) * v.tangent.w * unity_WorldTransformParams.w;
                o.tSpace0 = float3(t.x, b.x, n.x);
                o.tSpace1 = float3(t.y, b.y, n.y);
                o.tSpace2 = float3(t.z, b.z, n.z);

                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 tn = UnpackNormal(tex2D(_NormalMap, i.uv));
                tn.xy *= _NormalStrength;
                float3 n = normalize(float3(dot(i.tSpace0, tn), dot(i.tSpace1, tn), dot(i.tSpace2, tn)));

                float ao = lerp(1, tex2D(_MaskMap, i.uv).g, _AOStrength);
                float wet = 1 - saturate((i.worldPos.y - _WaterHeight) / max(_WetHeight, 1e-4));

                fixed4 baseColor = lerp(_ColorNight, _Color, _DayNightCycle);
                float3 albedo = baseColor.rgb * tex2D(_Tex, i.uv).rgb * (1 - wet * _WetDarken);

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                float3 sun = _LightColor0.rgb * saturate(dot(n, _WorldSpaceLightPos0.xyz)) * atten;
                float3 ambient = (ShadeSH9(float4(n, 1)) + _Ambient) * ao;

                fixed4 col = fixed4(albedo * (ambient + sun), _Glow);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"

            struct v2f
            {
                V2F_SHADOW_CASTER;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
}
