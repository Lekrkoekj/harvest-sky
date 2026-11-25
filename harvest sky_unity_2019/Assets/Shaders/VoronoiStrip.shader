Shader "Vivify/VoronoiStrip"
{
    Properties
    {
        [HDR] _Color ("Color", Color) = (0, 1, 0.8, 1)
        _Brightness ("Brightness", Range(0, 1)) = 1
        _Intensity ("Intensity", Float) = 3
        _Glow ("Glow", Range(0, 1)) = 1
        _Cutoff ("Cutoff", Range(0, 0.2)) = 0.01

        [Header(Strip UV)]
        _Aspect ("Strip Length / Width", Float) = 10

        [Header(Voronoi)]
        _Scale ("Cell Scale", Float) = 3
        _EdgeWidth ("Edge Width", Range(0, 0.5)) = 0.03
        _EdgeSoftness ("Edge Softness", Range(0.001, 0.5)) = 0.08
        _CellSpeed ("Cell Movement Speed", Float) = 0.5
        _Scroll ("Scroll Speed (XY)", Vector) = (0.1, 0, 0, 0)

        [Header(Circle Mask)]
        _MaskCenter ("Mask Center (UV XY)", Vector) = (0.5, 0.5, 0, 0)
        _MaskSize ("Mask Size", Float) = 0.5
        _MaskWidth ("Mask Width (Stretch Along Strip)", Float) = 1
        _MaskSoftness ("Mask Softness", Range(0.001, 1)) = 0.5
    }

    CGINCLUDE
    #include "UnityCG.cginc"

    float _Brightness;
    float _Cutoff;
    float _Aspect;
    float _Scale;
    float _EdgeWidth;
    float _EdgeSoftness;
    float _CellSpeed;
    float4 _Scroll;
    float4 _MaskCenter;
    float _MaskSize;
    float _MaskWidth;
    float _MaskSoftness;

    float2 Hash2(float2 p)
    {
        p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
        return frac(sin(p) * 43758.5453);
    }

    float2 CellPoint(float2 cell)
    {
        return 0.5 + 0.5 * sin(_Time.y * _CellSpeed + 6.2831 * Hash2(cell));
    }

    float VoronoiEdge(float2 x)
    {
        float2 n = floor(x);
        float2 f = frac(x);
        float2 mg = 0;
        float2 mr = 0;
        float md = 8;

        [unroll] for (int j = -1; j <= 1; j++)
        [unroll] for (int i = -1; i <= 1; i++)
        {
            float2 g = float2(i, j);
            float2 r = g + CellPoint(n + g) - f;
            float d = dot(r, r);
            if (d < md) { md = d; mr = r; mg = g; }
        }

        md = 8;
        [unroll] for (int y = -2; y <= 2; y++)
        [unroll] for (int x2 = -2; x2 <= 2; x2++)
        {
            float2 g = mg + float2(x2, y);
            float2 r = g + CellPoint(n + g) - f;
            float2 diff = r - mr;
            if (dot(diff, diff) > 0.00001)
                md = min(md, dot(0.5 * (mr + r), normalize(diff)));
        }
        return md;
    }

    float StripPattern(float2 uv)
    {
        float2 stretch = float2(_Aspect, 1);
        float2 p = uv * stretch;

        float edge = VoronoiEdge(p * _Scale + _Scroll.xy * _Time.y);
        float aa = fwidth(edge);
        float lines = 1 - smoothstep(_EdgeWidth - aa, _EdgeWidth + _EdgeSoftness + aa, edge);

        float2 offset = (p - _MaskCenter.xy * stretch) / max(float2(_MaskSize * _MaskWidth, _MaskSize), 1e-4);
        float mask = 1 - smoothstep(1 - _MaskSoftness, 1, length(offset));

        return lines * mask * _Brightness;
    }
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="AlphaTest+48" "IgnoreProjector"="True" }

        Pass
        {
            Name "FORWARD"
            Blend One One
            ZWrite On
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _Color;
            float _Intensity;
            float _Glow;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float intensity = StripPattern(i.uv);
                clip(intensity - _Cutoff);

                fixed4 col;
                col.rgb = _Color.rgb * intensity * _Intensity;
                col.a = saturate(intensity) * _Glow;

                UNITY_APPLY_FOG_COLOR(i.fogCoord, col, fixed4(0, 0, 0, 0));
                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing

            struct v2f
            {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.uv = v.texcoord.xy;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                clip(StripPattern(i.uv) - _Cutoff);
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
}
