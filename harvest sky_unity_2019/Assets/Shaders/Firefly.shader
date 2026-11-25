Shader "Vivify/Firefly"
{
    Properties
    {
        [HDR] _Color ("Color", Color) = (1, 1, 1, 1)
        _Brightness ("Brightness", Range(0, 10)) = 2
        _Glow ("Glow", Range(0, 1)) = 1
        _Core ("Core Size", Range(0.01, 1)) = 0.15
        _Falloff ("Halo Falloff", Range(1, 8)) = 3
        _NearFade ("Near Camera Fade", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="AlphaTest+49" "IgnoreProjector"="True" }

        Pass
        {
            Blend One One
            ZWrite On
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float fade : TEXCOORD1;
                UNITY_FOG_COORDS(2)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _Color;
            float _Brightness;
            float _Glow;
            float _Core;
            float _Falloff;
            float _NearFade;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.color;
                o.uv = v.uv * 2 - 1;

                float viewDepth = -UnityObjectToViewPos(v.vertex).z;
                o.fade = saturate((viewDepth - _NearFade) / max(_NearFade, 0.001));

                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float d = length(i.uv);
                float core = 1 - smoothstep(0, _Core, d);
                float halo = pow(saturate(1 - d), _Falloff);
                float shape = saturate(core + halo) * i.color.a * i.fade;
                clip(shape * _Brightness - 0.02);
                float intensity = shape * _Brightness;

                fixed4 col;
                col.rgb = i.color.rgb * _Color.rgb * intensity;
                col.a = intensity * _Glow;

                UNITY_APPLY_FOG_COLOR(i.fogCoord, col, fixed4(0, 0, 0, 0));
                return col;
            }
            ENDCG
        }
    }
}
