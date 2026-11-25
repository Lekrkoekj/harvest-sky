Shader "Vivify/Crystal"
{
    Properties
    {
        _Brightness ("Brightness", Range(0, 1)) = 1
        _Intensity ("Intensity", Range(0, 4)) = 1
        _Glow ("Glow", Range(0, 1)) = 0.5
        _MinGlow ("Min Glow When Off", Range(0, 0.2)) = 0.01

        [Header(Spectrum)]
        _SpectrumScale ("Spectrum Scale", Range(0, 6)) = 2
        _SpectrumOffset ("Spectrum Offset", Range(0, 1)) = 0
        _Perturb ("Perturb Strength", Range(0, 0.3)) = 0.05
        _PerturbFreq ("Perturb Frequency", Float) = 10
        _VertexColorMix ("Vertex Color Tint", Range(0, 1)) = 0

        [Header(Lighting)]
        _LightDir ("Light Direction", Vector) = (0.5, 1, -0.5, 0)
        _RingSpecular ("Ring Specular", Range(0, 1)) = 0.1
        _RingCount ("Ring Count", Range(1, 60)) = 20
        _SoftSpecular ("Soft Specular", Range(0, 1)) = 0.1
        _DomeShadow ("Dome Shadow", Range(0, 1)) = 1
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
            float _Intensity;
            float _Glow;
            float _MinGlow;
            float _SpectrumScale;
            float _SpectrumOffset;
            float _Perturb;
            float _PerturbFreq;
            float _VertexColorMix;
            float4 _LightDir;
            float _RingSpecular;
            float _RingCount;
            float _SoftSpecular;
            float _DomeShadow;

            float3 Spectrum(float t)
            {
                return 0.5 + 0.5 * cos(6.28318 * (t + float3(0, 0.33, 0.67)));
            }

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
                float3 rd = normalize(i.worldPos - _WorldSpaceCameraPos);
                float3 ref = reflect(rd, n);
                float3 lig = normalize(_LightDir.xyz);

                float3 perturb = sin(i.worldPos * _PerturbFreq);
                float3 col = Spectrum(dot(n + perturb * _Perturb, -rd) * _SpectrumScale + _SpectrumOffset);
                col = lerp(col, i.color * (0.6 + 0.8 * Luminance(col)), _VertexColorMix);

                float s = saturate(dot(ref, lig));
                float specular = pow(sin(s * _RingCount - 3) * 0.5 + 0.6, 32) * s * _RingSpecular;
                specular += pow(s + 0.3, 8) * _SoftSpecular;

                float shadow = pow(saturate(n.y * 0.5 + 1.2), 3);
                shadow = lerp(1, shadow, _DomeShadow);

                float visible = saturate(_Brightness + _MinGlow);

                fixed4 finalCol;
                finalCol.rgb = (col * shadow + specular) * _Intensity * visible;
                finalCol.a = visible * _Glow;

                UNITY_APPLY_FOG(i.fogCoord, finalCol);
                return finalCol;
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
