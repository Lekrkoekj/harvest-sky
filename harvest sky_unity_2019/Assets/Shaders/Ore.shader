Shader "Vivify/Ore"
{
    Properties
    {
        _Brightness ("Brightness", Range(0, 1)) = 1
        _Emission ("Emission Strength", Range(0, 10)) = 3
        _Glow ("Glow", Range(0, 1)) = 1

        [Header(Crystal)]
        _BodyColor ("Body Darkness", Range(0, 1)) = 0.15
        _CoreFalloff ("Core Falloff", Range(0, 8)) = 2
        _MinGlow ("Min Glow When Off", Range(0, 0.2)) = 0.01

        [Header(Gloss)]
        _RimStrength ("Rim Strength", Range(0, 4)) = 1.5
        _RimPower ("Rim Power", Range(0.5, 8)) = 3
        _RimWhiteness ("Rim Whiteness", Range(0, 1)) = 0.8
        _SpecStrength ("Specular Strength", Range(0, 4)) = 1.5
        _Gloss ("Glossiness", Range(1, 512)) = 128
        _HighlightDir ("Highlight Direction", Vector) = (0.4, 1, -0.3, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "FORWARD"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 color : TEXCOORD2;
                UNITY_FOG_COORDS(3)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float _Brightness;
            float _Emission;
            float _Glow;
            float _BodyColor;
            float _CoreFalloff;
            float _MinGlow;
            float _RimStrength;
            float _RimPower;
            float _RimWhiteness;
            float _SpecStrength;
            float _Gloss;
            float4 _HighlightDir;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);

                o.color = v.color.rgb;
                #ifndef UNITY_COLORSPACE_GAMMA
                    o.color = GammaToLinearSpace(o.color);
                #endif

                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 n = normalize(i.normal);
                float3 v = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 hFake = normalize(normalize(_HighlightDir.xyz) + v);
                float NdotV = saturate(dot(n, v));

                float on = saturate(_Brightness);
                float visible = saturate(on + _MinGlow);
                float fresnel = pow(1 - NdotV, _RimPower);

                float3 body = i.color * _BodyColor;
                float3 core = i.color * pow(NdotV, _CoreFalloff) * (_Emission * on + _MinGlow);
                float3 rim = lerp(i.color, 1, _RimWhiteness) * fresnel * _RimStrength * visible;

                float specNorm = (_Gloss + 8) / 25.1327;
                float specular = pow(saturate(dot(n, hFake)), _Gloss) * specNorm * _SpecStrength * visible;

                fixed4 col;
                col.rgb = body + core + rim + specular;
                col.a = saturate((on + _MinGlow) * _Glow);

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

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
