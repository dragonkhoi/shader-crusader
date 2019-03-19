Shader "Custom/Anisotropic"
{
    Properties
    {
        _Color("Diffuse Material Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Material Color", Color) = (1,1,1,1)
        _Ax("Roughness in brush's direction on surface", Float) = 1.0
        _Ay("Roughness orthogonal to brush's direction on surface", Float) = 1.0
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
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0
            
            static const float PI = 3.14159265f;
            uniform float4 _Color;
            uniform float4 _SpecularColor;
            uniform float _Ax;
            uniform float _Ay;

            struct v2f
            {
                //float2 uv : TEXCOORD0;
                //  fixed4 diff : COLOR0; // diffuse lighting color
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD0;
                float3 V : TEXCOORD1;
                float3 N : TEXCOORD2;
                float3 T : TEXCOORD3;
            };
            
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
                float alphaP = 1.0;
                float thetaV = 1.0;
                float a = sqrt(0.5 * alphaP + 1)/tan(thetaV);
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
                o.N = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz); // , unity_ObjectToWorld));
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                o.V = normalize(_WorldSpaceCameraPos - o.worldPos.xyz);
                o.T = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                return o;
            }
            
            sampler2D _MainTex;

            fixed4 frag (v2f input) : SV_Target
            {
                float Nt = 1.5;
                float Ni = 1.5;
                float3 i = normalize(_WorldSpaceLightPos0.xyz); // light dir
                float m = normalize(input.N); // TODO: microsurface normal
                float c = dot(i,m);
                float g = sqrt(max(0.0,(Nt * Nt) / (Ni * Ni) - 1 + c*c));
                float F;
                if (g == 0.0)
                {
                    F = 1.0;
                }
                else {
                    0.5 * ( (g - c) * (g - c) ) / ( (g + c) * (g + c) ) * ( 1 + pow((c*(g+c) - 1), 2)/pow((c*(g-c) + 1), 2));
                }
                half3 o = normalize(_WorldSpaceLightPos0.xyz); // light scattering TODO
                float G = shadowMasking(i, m, input.N) * shadowMasking (o, m, input.N);
                half3 n = normalize(input.N);
                half3 ht = normalize(i + o); // TODO: check
                float D = 1.0; // stefan here
                float freflection = F * G * D / (4*length(dot(i, input.N))*length(dot(o,input.N)));
                float frefractionLead = (length(dot(i, ht)) * length(dot(o, ht))) / (length(dot(i, n)) * length(dot(o, n)));
                float frefraction = frefractionLead * (Nt * Nt * (1 - F) * G * D) / pow((Ni*(dot(i, ht)) + Nt*dot(o,ht)), 2);
                float bxdf = freflection + frefraction;
                
                half3 L = normalize(_WorldSpaceLightPos0.xyz); //  -i.worldPos);
                half3 V = input.V;
                half3 H = normalize(V + L);
                half3 N = input.N;
                half3 T = input.T;
                half3 B = cross(N, T);
                float LN = dot(L, N);
                
                float thetaM = acos(2);

                float3 ambientLight = UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;
                
                fixed3 wardSpec;
                if (LN < 0.0) {
                    wardSpec = fixed3(0.0, 0.0, 0.0);
                }
                else {
                    float ps = 1.0;
                    float kSpec = ps / (4 * PI * _Ax * _Ay);
                    float dotHT = dot(H, T) / _Ax;
                    float dotHB = dot(H, B) / _Ay;
                    float exponent = -2.0 * (dotHT * dotHT + dotHB * dotHB) /
                        (1.0f + dot(H, N));
                    wardSpec = _LightColor0.rgb * _SpecularColor.rgb * sqrt(max(0.0, LN / dot(V, N))) * exp(exponent);
                }
                float3 diff = float3(_Color.rgb) * float3(_LightColor0.rgb) * max(0.0, LN);

                fixed4 col = float4(ambientLight + wardSpec + diff, 1.0); // float4(1.0,1.0,1.0,1.0); // //tex2D(_MainTex, i.uv);

                return col;
            }
            ENDCG
        }
    }
}