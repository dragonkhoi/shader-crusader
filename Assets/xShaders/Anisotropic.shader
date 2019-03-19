Shader "Custom/Anisotropic"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}
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
            
            struct v2f
            {
                //float2 uv : TEXCOORD0;
                fixed4 diff : COLOR0; // diffuse lighting color
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD0;
                float3 V : TEXCOORD1;
                float3 N : TEXCOORD2;
                float3 T : TEXCOORD3;
            };

            v2f vert (appdata_full v)
            {   
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                // o.uv = v.texcoord;
                // get vertex normal in world space
                half3 N = normalize (mul(v.normal, unity_WorldToObject));
                // dot product between normal and light direction for
                // standard diffuse (Lambert) lighting
                o.worldPos = mul(v.vertex, unity_ObjectToWorld);
                
                half3 V = normalize(_WorldSpaceCameraPos - mul(v.vertex, unity_ObjectToWorld));
                o.V = V;
                o.N = N;
                o.T = normalize(mul(v.tangent, unity_ObjectToWorld));
                half nl = max (0, dot(N, _WorldSpaceLightPos0.xyz));
                
                // factor in the light color
                o.diff = nl * _LightColor0;//  * wardSpec;
                //o.diff = _LightColor0 * wardSpec;
                return o;
            }
            
            sampler2D _MainTex;

            fixed4 frag (v2f i) : SV_Target
            {
                half3 L = normalize(_WorldSpaceLightPos0 - i.worldPos);
                half3 V = i.V;
                half3 N = i.N;
                half3 H = normalize(V + L);
                half3 T = i.T;
                half3 B = cross(N, T);
                float ax = 1.0;
                float ay = 1.0;
                float ps = 1.0;
                float kSpec = ps / (4 * PI * ax * ay);
                float exponent = -2.0 * (pow((dot(H, T) / ax), 2) + pow(dot(H, B) / ay, 2)) /
                                        (1.0f + dot(H, N));
                
                fixed4 wardSpec = kSpec * 1.0f / (sqrt(dot(L, N) * dot(V, N))) * exp(exponent);
                // sample texture
                fixed4 col = wardSpec;//tex2D(_MainTex, i.uv);
                // multiply by lighting
                col *= i.diff;
                return col;
            }
            ENDCG
        }
    }
}