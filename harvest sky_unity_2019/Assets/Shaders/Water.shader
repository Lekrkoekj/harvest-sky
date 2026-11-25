Shader "Vivify/Water"
{
    Properties
    {
        _Color ("Base Color", Color) = (0.02, 0.03, 0.04, 1)
        _Reflectivity ("Reflectivity", Range(0, 1)) = 1
        _FresnelBase ("Fresnel Base", Range(0, 1)) = 0.3
        _FresnelPower ("Fresnel Power", Range(0.5, 8)) = 4

        [Header(Ripples)]
        _WaveScale ("Wave Scale", Float) = 0.4
        _WaveSpeed ("Wave Speed", Float) = 0.3
        _WaveStrength ("Wave Strength", Range(0, 1)) = 0.15
        _WaveFade ("Distance Fade", Range(0, 10)) = 3

        [Header(Blur)]
        _Blur ("Blur", Range(0, 0.2)) = 0.05
        _MaxBlur ("Max Blur", Range(0, 0.05)) = 0.015

        [Header(Ray March)]
        _MaxDistance ("Max Ray Distance", Float) = 60
        _Steps ("Ray Steps", Range(8, 128)) = 64
        _Thickness ("Hit Thickness", Float) = 1.5
        _ThicknessFade ("Thickness Fade Start", Range(0, 1)) = 0.2
        _EdgeFade ("Screen Edge Fade", Range(0.001, 0.5)) = 0.05
        _FarDistance ("Far Field Start", Float) = 150
        _ProbeStrength ("Reflection Probe Fallback", Range(0, 1)) = 1
        _ProbeBlur ("Probe Blur", Range(0, 6)) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="AlphaTest+50" }

        GrabPass { "_WaterGrabTexture" }

        Pass
        {
            ZWrite On
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"
            #include "../VivifyTemplate/Utilities/Shader Functions/Noise.cginc"

            #if defined(UNITY_STEREO_INSTANCING_ENABLED)
                #define SAMPLE_SCREEN_LOD(tex, uv) UNITY_SAMPLE_TEX2DARRAY_LOD(tex, float3(uv, (float)unity_StereoEyeIndex), 0)
            #else
                #define SAMPLE_SCREEN_LOD(tex, uv) tex2Dlod(tex, float4(uv, 0, 0))
            #endif

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
                UNITY_VERTEX_OUTPUT_STEREO
            };

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_WaterGrabTexture);
            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthTexture);

            float4 _Color;
            float _Reflectivity;
            float _FresnelBase;
            float _FresnelPower;
            float _WaveScale;
            float _WaveSpeed;
            float _WaveStrength;
            float _WaveFade;
            float _Blur;
            float _MaxBlur;
            float _MaxDistance;
            float _Steps;
            float _Thickness;
            float _ThicknessFade;
            float _EdgeFade;
            float _FarDistance;
            float _ProbeStrength;
            float _ProbeBlur;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float WaveHeight(float2 p)
            {
                float time = _Time.y * _WaveSpeed;
                float h = simplex(float3(p * _WaveScale, time));
                h += 0.5 * simplex(float3(p * _WaveScale * 2.3 + 17.1, time * 1.4));
                return h;
            }

            float3 RippleNormal(float3 worldPos, float3 n, float strength)
            {
                float2 p = worldPos.xz;
                float eps = 0.05;
                float h = WaveHeight(p);
                float dx = (WaveHeight(p + float2(eps, 0)) - h) / eps;
                float dz = (WaveHeight(p + float2(0, eps)) - h) / eps;

                float3 t = normalize(cross(n, float3(0, 0, 1)));
                float3 b = cross(t, n);
                return normalize(n - (t * dx + b * dz) * strength);
            }

            float4 WorldToClip(float3 p)
            {
                return mul(UNITY_MATRIX_VP, float4(p, 1));
            }

            float2 ClipToDepthUV(float4 clip)
            {
                float4 s = ComputeScreenPos(clip);
                return s.xy / s.w;
            }

            float2 ClipToGrabUV(float4 clip)
            {
                float4 s = ComputeGrabScreenPos(clip);
                return s.xy / s.w;
            }

            struct Ray
            {
                float2 uv0, uv1;
                float2 grab0, grab1;
                float k0, k1;
            };

            float RayDepth(Ray ray, float t)
            {
                return 1 / lerp(ray.k0, ray.k1, t);
            }

            float DepthDifference(Ray ray, float t)
            {
                float2 uv = lerp(ray.uv0, ray.uv1, t);
                float sceneDepth = LinearEyeDepth(SAMPLE_SCREEN_LOD(_CameraDepthTexture, uv).r);
                return RayDepth(ray, t) - sceneDepth;
            }

            float ExitT(float2 start, float2 dir)
            {
                float2 bound = dir > 0 ? 1 - start : -start;
                float2 t = abs(dir) > 1e-6 ? bound / dir : 1e6;
                return saturate(min(t.x, t.y));
            }

            fixed4 SampleBlurred(float2 depthUV, float2 grabUV, float minDepth, float radius, float rotation)
            {
                #if UNITY_UV_STARTS_AT_TOP
                    float flipY = -_ProjectionParams.x;
                #else
                    float flipY = _ProjectionParams.x;
                #endif

                fixed4 sum = SAMPLE_SCREEN_LOD(_WaterGrabTexture, grabUV);
                float weight = 1;

                [unroll]
                for (int k = 0; k < 8; k++)
                {
                    float a = k * 2.39996 + rotation;
                    float2 o = float2(cos(a), sin(a)) * sqrt((k + 0.5) / 8) * radius;
                    float tapDepth = LinearEyeDepth(SAMPLE_SCREEN_LOD(_CameraDepthTexture, depthUV + o).r);
                    float w = tapDepth >= minDepth;
                    sum += SAMPLE_SCREEN_LOD(_WaterGrabTexture, grabUV + float2(o.x, o.y * flipY)) * w;
                    weight += w;
                }
                return sum / weight;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 surfaceNormal = normalize(i.normal);
                float footprint = length(fwidth(i.worldPos)) * _WaveScale;
                float waveFade = saturate(1 - footprint * _WaveFade);
                float3 n = RippleNormal(i.worldPos, surfaceNormal, _WaveStrength * waveFade * waveFade);
                float3 viewDir = normalize(i.worldPos - _WorldSpaceCameraPos);
                float3 r = reflect(viewDir, n);

                float4 c0 = WorldToClip(i.worldPos);
                float rayLength = _MaxDistance;
                float w1 = WorldToClip(i.worldPos + r * rayLength).w;
                float nearW = _ProjectionParams.y;
                if (w1 < nearW) rayLength *= (c0.w - nearW) / (c0.w - w1) * 0.99;
                float4 c1 = WorldToClip(i.worldPos + r * rayLength);

                Ray ray;
                ray.uv0 = ClipToDepthUV(c0);
                ray.uv1 = ClipToDepthUV(c1);
                ray.grab0 = ClipToGrabUV(c0);
                ray.grab1 = ClipToGrabUV(c1);
                ray.k0 = 1 / c0.w;
                ray.k1 = 1 / c1.w;

                float tMax = ExitT(ray.uv0, ray.uv1 - ray.uv0);
                float dt = tMax / _Steps;
                float noise = frac(52.9829189 * frac(dot(i.pos.xy, float2(0.06711056, 0.00583715))));

                float prevT = 0;
                float prevDiff = -1;
                float t = dt * noise;
                bool hit = false;
                float hitDiff = 0;

                [loop]
                for (int s = 0; s < (int)_Steps; s++)
                {
                    t += dt;
                    if (t > tMax) break;

                    float diff = DepthDifference(ray, t);
                    if (prevDiff <= 0 && diff > 0)
                    {
                        float front = prevT;
                        float back = t;
                        float backDiff = diff;

                        [unroll]
                        for (int b = 0; b < 6; b++)
                        {
                            float mid = (front + back) * 0.5;
                            float midDiff = DepthDifference(ray, mid);
                            if (midDiff > 0)
                            {
                                back = mid;
                                backDiff = midDiff;
                            }
                            else front = mid;
                        }

                        if (backDiff < _Thickness)
                        {
                            t = back;
                            hitDiff = backDiff;
                            hit = true;
                            break;
                        }
                    }
                    prevDiff = diff;
                    prevT = t;
                }

                fixed4 reflection = 0;
                float mask = 0;

                if (hit)
                {
                    float pixelT = 1.5 / max(length((ray.uv1 - ray.uv0) * _ScreenParams.xy), 1);
                    t = min(t + pixelT, tMax);

                    float2 uv = lerp(ray.uv0, ray.uv1, t);
                    float rawDepth = SAMPLE_SCREEN_LOD(_CameraDepthTexture, uv).r;
                    float2 edge = min(uv, 1 - uv);
                    mask = saturate(min(edge.x, edge.y) / _EdgeFade);
                    mask *= Linear01Depth(rawDepth) < 0.999;
                    mask *= 1 - smoothstep(_Thickness * _ThicknessFade, _Thickness, hitDiff);
                    float radius = min(length(uv - ray.uv0) * _Blur, _MaxBlur);
                    float hitDepth = LinearEyeDepth(rawDepth);
                    reflection = SampleBlurred(uv, lerp(ray.grab0, ray.grab1, t), hitDepth * 0.9 - 0.2, radius, noise * 6.2832);
                }

                fixed4 sky = 0;
                float skyMask = 0;

                if (mask < 1)
                {
                    float4 skyClip = mul(UNITY_MATRIX_VP, float4(r, 0));
                    if (skyClip.w > 0)
                    {
                        float2 uv = ClipToDepthUV(skyClip);
                        float2 edge = min(uv, 1 - uv);
                        if (all(edge > 0) && LinearEyeDepth(SAMPLE_SCREEN_LOD(_CameraDepthTexture, uv).r) >= _FarDistance)
                        {
                            skyMask = saturate(min(edge.x, edge.y) / _EdgeFade);
                            float radius = min(length(uv - ray.uv0) * _Blur, _MaxBlur);
                            sky = SampleBlurred(uv, ClipToGrabUV(skyClip), _FarDistance, radius, noise * 6.2832);
                        }
                    }
                }

                float3 probeDir = BoxProjectedCubemapDirection(r, i.worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                float3 probe = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, probeDir, _ProbeBlur), unity_SpecCube0_HDR) * _ProbeStrength;
                float3 env = lerp(lerp(probe, sky.rgb, skyMask), reflection.rgb, mask);
                reflection.a = lerp(sky.a * skyMask, reflection.a, mask);
                mask = 1;

                float NdotV = saturate(dot(surfaceNormal, -viewDir));
                float fresnel = _FresnelBase + (1 - _FresnelBase) * pow(1 - NdotV, _FresnelPower);
                float amount = _Reflectivity * fresnel;

                float3 col = lerp(_Color.rgb, env, amount);
                float glow = reflection.a * mask * amount;

                return fixed4(col, glow);
            }
            ENDCG
        }
    }
}
