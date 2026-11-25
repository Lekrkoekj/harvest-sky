Shader "Vivify/Laser"
{
    Properties
    {
        [HDR] _Color ("Color", Color) = (0, 1, 0.7, 1)
        _Brightness ("Brightness", Range(0, 1)) = 1
        _Intensity ("Intensity", Float) = 3
        _Glow ("Glow", Range(0, 1)) = 1
        _CoreWhiteness ("Core Whiteness", Range(0, 1)) = 0.6
        _EdgeSoftness ("Edge Softness", Range(0.5, 8)) = 2

        [Header(Rotation)]
        _Speed ("Rotation Speed (Beat Saber value)", Float) = 0
        _Offset ("Rotation Offset (deg)", Float) = 0
        _SpinAxis ("Spin Axis (World)", Vector) = (0, 1, 0, 0)
        _PivotHeight ("Pivot Height (Local)", Float) = 1
    }

    CGINCLUDE
    #include "UnityCG.cginc"

    float4 _Color;
    float _Brightness;
    float _Speed;
    float _Offset;
    float4 _SpinAxis;
    float _PivotHeight;

    float3 RotateAround(float3 p, float3 axis, float angle)
    {
        float s, c;
        sincos(angle, s, c);
        return p * c + cross(axis, p) * s + axis * dot(axis, p) * (1 - c);
    }

    float LaserLevel()
    {
        return max(max(_Color.r, _Color.g), _Color.b) * _Color.a * _Brightness;
    }

    void Spin(float4 vertex, float3 normal, out float3 worldPos, out float3 worldNormal)
    {
        float angle = radians(_Offset + _Time.y * _Speed * 20);
        float3 axis = normalize(_SpinAxis.xyz);
        float3 pivot = mul(unity_ObjectToWorld, float4(0, -_PivotHeight, 0, 1)).xyz;

        worldPos = mul(unity_ObjectToWorld, vertex).xyz;
        worldPos = pivot + RotateAround(worldPos - pivot, axis, angle);
        worldNormal = RotateAround(UnityObjectToWorldNormal(normal), axis, angle);
    }
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="AlphaTest+48" }

        Pass
        {
            Name "FORWARD"
            Blend One One
            ZWrite On
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                UNITY_FOG_COORDS(2)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float _Intensity;
            float _Glow;
            float _CoreWhiteness;
            float _EdgeSoftness;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                Spin(v.vertex, v.normal, o.worldPos, o.normal);
                o.pos = UnityWorldToClipPos(o.worldPos);

                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 n = normalize(i.normal);
                float3 v = normalize(_WorldSpaceCameraPos - i.worldPos);
                float core = pow(saturate(dot(n, v)), _EdgeSoftness);
                float level = LaserLevel();
                float3 hue = _Color.rgb / max(max(max(_Color.r, _Color.g), _Color.b), 1e-4);
                float intensity = core * level;
                clip(intensity - 0.01);

                fixed4 col;
                col.rgb = lerp(hue, 1, _CoreWhiteness * core * core) * intensity * _Intensity;
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

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                V2F_SHADOW_CASTER;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 worldPos, worldNormal;
                Spin(v.vertex, v.normal, worldPos, worldNormal);
                v.vertex = mul(unity_WorldToObject, float4(worldPos, 1));
                v.normal = mul(worldNormal, (float3x3)unity_ObjectToWorld);

                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                clip(LaserLevel() - 0.01);
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
}
