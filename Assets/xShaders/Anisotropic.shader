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

            fixed4 frag (v2f i) : SV_Target
            {
				half3 L = normalize(_WorldSpaceLightPos0.xyz); //  -i.worldPos);
                half3 V = i.V;
				half3 H = normalize(V + L);
                half3 N = i.N;
                half3 T = i.T;
                half3 B = cross(N, T);
				float LN = dot(L, N);

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