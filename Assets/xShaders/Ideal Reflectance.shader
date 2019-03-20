Shader "Custom/Anisotropic"
{
    Properties
    {
        _Color("Diffuse Material Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Material Color", Color) = (1,1,1,1)
        _Ax("Roughness in brush's direction on surface", Float) = 1.0
        _Ay("Roughness orthogonal to brush's direction on surface", Float) = 1.0
        _AlphaP("Exponent parameter for calculating microsurface normal", Float) = 1.0
    }
    SubShader
    {
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
            uniform float _Ax;
            uniform float _Ay;
            uniform float _AlphaP;
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                //  fixed4 diff : COLOR0; // diffuse lighting color
                float4 vertex : SV_POSITION;
                float3 V : TEXCOORD1;
                float3 N : TEXCOORD2;
                float3 T : TEXCOORD3;
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

            float shadowMasking (half3 v, half3 m, half3 n)
            {
                float G;
                float dotVM = dot(v, m);
                float dotVN = dot(v, n);
                float chiPlus;
                if (dotVM / dotVN > 0)
                {
                    chiPlus = 1.0;
                }
                else 
                {
                    chiPlus = 0.0;
                }
                float thetaV = threeDToPolar(v).x;
                float a = sqrt(0.5 * _AlphaP + 1)/tan(thetaV);
                float piecewise;
                if (a < 1.6){
                    piecewise = (3.535 * a + 2.181 * a * a ) / (1 + 2.276*a + 2.577*a*a);
                
                }
                else
                {
                    piecewise = 1.0;
                }
                G = chiPlus * piecewise;
                return G;
            }

            v2f vert (appdata_full v)
            {   
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.N = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);   
                o.V = normalize(_WorldSpaceCameraPos - o.vertex.xyz);
                o.T = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.uv = v.texcoord;
                return o;
            }
            
            sampler2D _MainTex;
            
            float fresnel(half3 i, half3 m, float Nt, float Ni)
            {
                float c = abs(dot(i,m));
                float g = sqrt(max(0.0,(Nt * Nt) / (Ni * Ni) - 1 + c*c));
                float F;
                if (g == 0.0)
                    F = 1.0;
                else
                    F = 0.5 * ( (g - c) * (g - c) ) / ( (g + c) * (g + c) ) * ( 1 + pow((c*(g+c) - 1), 2)/pow((c*(g-c) + 1), 2));
                    
                return F;
            }

            fixed4 frag (v2f input) : SV_Target
            {
                float Nt = 1.5;
                float Ni = 1.5;
                float3 i = normalize(WorldSpaceLightDir(input.vertex)); // light dir
                // Get coordinates of microsurface
                float random1 = frac(rand(input.uv));
                float random2 = frac(rand(input.vertex.xy));
                float thetaM = acos(pow(random1, 1 / (_AlphaP + 2)));
                float phiM = 2 * PI * random2;

                float3 M = polarTo3D(thetaM, phiM); 
                
                
                
                half3 n = normalize(input.N);
                half3 o = normalize(-i - 2 * dot(-i, n) * n); // light scattering TODO
                float G = shadowMasking(i, M, input.N) * shadowMasking (o, M, input.N);
                half3 hr = normalize(i + o); // TODO: check
                half3 ht = normalize (-Ni * i - Nt * o);
                
                float F = fresnel(i, hr, Nt, Ni);
                
                float MN = dot(M, n);
                float D = (MN > 0 ? 1 : 0) * (_AlphaP + 2) / (2 * PI) * pow(cos(thetaM), _AlphaP);
               
                
                
                float freflection = F * G * D / (4*abs(dot(i, n))*abs(dot(o,n)));
                float frefractionLead = (abs(dot(i, hr)) * abs(dot(o, ht))) / (abs(dot(i, n)) * abs(dot(o, n)));
                float frefraction = frefractionLead * (Nt * Nt * (1 - F) * G * D) / pow((Ni*(dot(i, ht)) + Nt*dot(o,ht)), 2);
                float bxdf = freflection + frefraction;
                
                half3 L = normalize(_WorldSpaceLightPos0.xyz);
                float LN = dot(L, n);
                
          
                float3 ambientLight = UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;
                float3 diff = float3(_Color.rgb) * float3(_LightColor0.rgb) * max(0.0, LN);
                fixed4 col = float4(ambientLight + bxdf + diff, 1.0);
                return col;
            }
            ENDCG
        }
    }
}