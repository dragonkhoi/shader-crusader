Shader "Custom/IdealReflectance"
{
    Properties
    {
        _Color("Diffuse Material Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Material Color", Color) = (1,1,1,1)
        _AlphaP("Exponent parameter for calculating microsurface normal", Float) = 1.0
        _Nt("Index of refraction on transmitted side", Float) = 1.5
        _Ni("Index of refraction on incident side", Float) = 1.5
    }
    SubShader
    {
    GrabPass {"_GrabTexture"}
        Pass
        {
            // indicate that our pass is the "base" pass in forward
            // rendering pipeline. It gets ambient and main directional
            // light data set up; light direction in _WorldSpaceLightPos0
            // and color in _LightColor0
            Tags {"LightMode"="ForwardBase"}
        
            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 because it uses wrong array syntax (type[size] name)
#pragma exclude_renderers d3d11
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0
            
            static const float PI = 3.14159265f;
            uniform float4 _Color;
            uniform float4 _SpecularColor;
            uniform float _AlphaP;
            uniform float _Nt;
            uniform float _Ni;
            sampler2D _GrabTexture;
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                //  fixed4 diff : COLOR0; // diffuse lighting color
                float4 vertex : SV_POSITION;
                float3 V : TEXCOORD1;
                float3 N : TEXCOORD2;
                float4 uvgrab : TEXCOORD3;
            };
            
            float rand(in float2 uv)
            {
                float2 noise = (frac(sin(dot(uv ,float2(12.9898,78.233)*2.0)) * 43758.5453));
                return abs(noise.x + noise.y) * 0.5;
            }
            
            float3 polarTo3D (float theta, float phi)
            {
                float3 result = (0,0,0);
                result.x = cos(theta) * cos(phi);
                result.y = sin(theta) * cos(phi);
                result.z = sin(phi);
                return result;
            }
            
            float2 threeDToPolar (float3 v)
            {
                float2 result = (0,0);
                float radius = sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
                result.x = atan2(v.y, v.x);
                result.y = acos(v.z / radius);
                return result;
            }    

            v2f vert (appdata_full v)
            {   
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.N = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);   
                o.V = normalize(_WorldSpaceCameraPos - o.vertex.xyz);
                o.uv = v.texcoord;
                o.uvgrab = ComputeGrabScreenPos(o.vertex);
                return o;
            }
            
            sampler2D _MainTex;
            
            float fresnel(half3 i, half3 m)
            {
                float c = abs(dot(i,m));
                float g = sqrt(max(0.0,(_Ni * _Ni) - 1 + c*c));
                float F;
                if (g == 0.0)
                    F = 1.0;
                else
                    F = 0.5 * ( (g - c) * (g - c) ) / ( (g + c) * (g + c) ) * ( 1 + pow((c*(g+c) - 1), 2)/pow((c*(g-c) - 1), 2));
                    
                return F;
            }
            
            float microSurfaceSampling (half3 h, half3 n, float2 seed)
            {
                // Get coordinates of microsurface
                float m = frac(rand(seed));
                //float random2 = frac(rand(input.vertex.xy));
                //float thetaM = acos(pow(random1, 1 / (_AlphaP + 2)));
                //float phiM = 2 * PI * random2;
                //float3 M = polarTo3D(thetaM, phiM);
                float nh = dot(n, h);
                //float thetaM = acos(mn / (length(m) * length(n)));
                float D = (nh > 0 ? 1 : 0) * (m + 2) * pow(nh, m) / (2 * PI);
                return D;
            }
            
            float shadowMasking (half3 l, half3 v, half3 h, half3 n)
            {
                //float G;
                //float dotVM = dot(v, m);
                //float dotVN = dot(v, n);
                //float chiPlus;
                //if (dotVM / dotVN > 0)
                //{
                //    chiPlus = 1.0;
                //}
                //else 
                //{
                //    chiPlus = 0.0;
                //}
                //float thetaV = threeDToPolar(v).x;
                //float a = sqrt(0.5 * _AlphaP + 1)/tan(thetaV);
                //float piecewise;
                //if (a < 1.6){
                //    piecewise = (3.535 * a + 2.181 * a * a ) / (1 + 2.276*a + 2.577*a*a);
                
                //}
                //else
                //{
                //    piecewise = 1.0;
                //}
                //G = chiPlus * piecewise;
                //return G;
                float maskTerm = 2 * dot(n,h) * dot(n,v) / dot (v,h);
                float shadowTerm = 2 * dot(n,h) * dot(n,l) / dot (v,h);
                float minTerm = min(maskTerm, shadowTerm);
                return min(1, minTerm);
            }

            fixed4 frag (v2f input) : SV_Target
            {
                float3 i = normalize(WorldSpaceLightDir(input.vertex)); // light dir
                
                half3 n = normalize(input.N);
                half3 o = normalize(2*abs(dot(i, n)) * n - i);
                half3 hr = normalize(i + input.V);
                half3 ht = normalize (-(_Ni * i + _Nt * o));
                              
                float Freflect = fresnel(input.V, hr);
                float Frefract = fresnel(input.V, ht);
                float Greflect = shadowMasking(i, input.V, hr, n);
                float Grefract = shadowMasking(i, input.V, ht, n);
                float Dreflect = microSurfaceSampling(hr, n, input.uv);
                float Drefract = microSurfaceSampling(ht, n, input.uv);
                
                float freflection = Freflect * Greflect * Dreflect / (4 * abs(dot(i, n)) * abs(dot(o, n)));
                float frefractionLead = (abs(dot(i, ht)) * abs(dot(o, ht))) / (abs(dot(i, n)) * abs(dot(o, n)));
                float frefraction = frefractionLead * (_Nt * _Nt * (1 - Frefract) * Grefract * Drefract) / pow((_Ni*(dot(i, ht)) + _Nt*dot(o,ht)), 2);

                float bxdf = freflection + frefraction;
                
                half3 L = normalize(_WorldSpaceLightPos0.xyz);
                float LN = dot(L, n);

                float3 ambientLight = UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;
                float3 diff = (_Color.rgb * _LightColor0.rgb + bxdf * _SpecularColor.rgb * _LightColor0.rgb) * max(0.0, LN) ;
                fixed4 col = float4(ambientLight + diff, 1.0);
                return bxdf;// * max(0.0, LN);
                //return col;
            }
            ENDCG
        }
    }
}