Shader "Custom/Ideal Reflectance"
{
    Properties
    {
        _Color("Diffuse Material Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Material Color", Color) = (1,1,1,1)
        _M("Roughness", Float) = 0.5
        _Ni("Refractive Index In", Float) = 1.0
        _No("Refractive Index Out", Float) = 1.5     
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "RenderType"="Transparent"}
        GrabPass{}
        
        Pass
        {
            // indicate that our pass is the "base" pass in forward
            // rendering pipeline. It gets ambient and main directional
            // light data set up; light direction in _WorldSpaceLightPos0
            // and color in _LightColor0
        
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0
            
            static const float PI = 3.14159265f;
            uniform float4 _Color;
            uniform float4 _SpecularColor;
            uniform float _M;
            uniform float _Ni;
            uniform float _No;
            sampler2D _GrabTexture;
            
            /* Schlick approximation
             * l = Light direction
             * h = Half vector between light and viewer */
            float Fresnel(float3 l, float3 h)
            {
                float f0 = pow((1.0 - _No) / (1.0 + _No), 2);
                return f0 + (1.0 - f0) * pow(1.0 - dot(l, h), 5);
            }
            
            /* Beckmann distribution
             * n = Macro surface normal
             * h = Half vector between light and viewer */
            float Beckmann (float3 n, float3 h)
            {
                float nh = max (dot(n, h), 0.0);
                // Don't divide by 0
                if (nh == 0.0)
                    return 0.0;
                float exponent = (pow(nh, 2) - 1) / (_M * _M * pow(nh, 2));
                return exp(exponent) / (PI * _M * _M * pow(nh, 4));
            }
            
            /* Schlick approximation shadow masking
             * l = Light direction
             * v = Viewer vector
             * h = Half vector between light and viewer
             * n = Macro surface normal */
            float Schlick (float3 l, float3 v, float3 h, float3 n)
            {
                float nl = max (dot(n, l), 0.0);
                float nv = max (dot(n, v), 0.0);
                float k = _M * sqrt(2.0 / PI);
                float G1l = nl / (nl * (1 - k) + k);
                float G1v = nv / (nv * (1 - k) + k);
                return G1l * G1v;
            }
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 v : TEXCOORD0;
                float3 n : TEXCOORD1;
                float3 l : TEXCOORD2;
            };
            
            // Vertex shader
            v2f vert (appdata_full v)
            {   
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.n = normalize(UnityObjectToWorldNormal(v.normal));   
                o.v = normalize(WorldSpaceViewDir(o.vertex));
                o.l = normalize(WorldSpaceLightDir(o.vertex)); 
                return o;
            }
            
            // Fragment shader
            fixed4 frag (v2f i) : SV_Target
            {
                // Reflection
                float3 h = normalize(i.l + i.v);
                float F = Fresnel(i.l, h);
                float G = Schlick(i.l, i.v, h, i.n);
                float D = Beckmann(i.n, h);
                float nl = max(dot(i.n, i.l), 0.0);
                float nv = max(dot(i.n, i.v), 0.0);
                float4 microfacetBRDF;
                // Don't divide by 0
                if (4.0 * nl * nv == 0)
                    microfacetBRDF = 0.0;
                else
                    microfacetBRDF = F * G * D / (4.0 * nl * nv);
                
                // Refraction
                float thetaIn = acos(dot(i.l, h));
                float thetaOut = asin(_Ni * sin(thetaIn) / _No);
                //float o = (_Ni / _No) * i.l + ((_Ni / _No) * cos(thetaIn) - sqrt(1 - (sin(thetaOut) * sin(thetaOut)))) * i.n;
                float3 o = refract(i.l, i.n, _Ni / _No);
                float3 ht = -normalize(_Ni * i.l + _No * o);
                float Ft = min(Fresnel(i.l, ht), 1.0);
                float Gt = Schlick(i.l, i.v, ht, i.n);
                float Dt = Beckmann(i.n, ht);
                float leadingTerm = abs(dot(i.l, ht)) * abs(dot(o, ht)) / (abs(dot(i.l, i.n)) * abs(dot(o, i.n)));
                float microfacetBTDF = leadingTerm * _No * _No * (1.0 - Ft) * Gt * Dt / pow(_Ni * dot(i.l, ht) + _No * dot(o, ht), 2);             
                
                float nlClamp = max(dot(i.n, i.l), 0.0);
                float3 spec = nl * (microfacetBRDF + microfacetBTDF) * _LightColor0;
                
                // Refraction of background texture
                float3 refractDir = normalize(refract(i.v, i.n, _Ni / _No));
                float4 refractPos = ComputeGrabScreenPos(UnityObjectToClipPos(refractDir));
                float2 refractCoords = (refractPos.xy / refractPos.w);
                #if UNITY_UV_STARTS_AT_TOP
                refractCoords.x = 1.0 - refractCoords.x;
                refractCoords.y = 1.0 - refractCoords.y;
                #endif
                float3 refractColor = tex2D(_GrabTexture, refractCoords) * _Color * _LightColor0;
                return float4 (refractColor + spec, 1.0);
            }
            
            ENDCG
        }
    }
}