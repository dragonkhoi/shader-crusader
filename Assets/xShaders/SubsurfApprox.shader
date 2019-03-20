Shader "Custom/Subsurf"
{
    Properties
    {
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
	    _Power("Power", Range(0.0, 4.0)) = 1.0
        _Distortion("Distortion", Range(0.0, 1.0)) = 1.0
        _Scale("Scale", Range(0.0, 1.0)) = 1.0
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
            #include "Lighting.cginc"

            // compile shader into multiple variants, with and without shadows
            // (we don't care about any lightmaps yet, so skip these variants)
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            // shadow helper functions and macros
            #include "AutoLight.cginc"
            
            static const float PI = 3.14159265f;
			float _Power;
            float _Distortion;
            float _Scale;

            struct v2f
            {
                float2 uv : TEXCOORD5;
                //  fixed4 diff : COLOR0; // diffuse lighting color
                float4 pos : SV_POSITION;
                float4 worldPos : TEXCOORD0;
                float3 V : TEXCOORD1;
                float3 N : TEXCOORD2;
                float3 T : TEXCOORD3;
                fixed3 ambient : COLOR1;
                SHADOW_COORDS(4)
            };

            v2f vert (appdata_full v)
            {   
                v2f o;
                o.uv = v.texcoord;
                o.pos = UnityObjectToClipPos(v.vertex);
				o.N = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz); // , unity_ObjectToWorld));
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                o.V = normalize(_WorldSpaceCameraPos - o.pos.xyz);
                o.T = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                 o.ambient = ShadeSH9(half4(o.N,1));
                // compute shadows data
                TRANSFER_SHADOW(o)
                return o;
            }
            
            sampler2D _MainTex;

            fixed4 frag (v2f i) : SV_Target
            {
				half3 L = -1*normalize(WorldSpaceLightDir(i.pos)); //  -i.worldPos);
                half3 V = i.V;
                half3 N = i.N;
				half3 H = normalize(N * _Distortion + L);
                
                float iBack = pow(saturate(dot(V, -H)), _Power) * _Scale;
                
                fixed4 texColor = tex2D(_MainTex, i.uv);
				
                float LN = dot(L, N);

				float3 ambientLight = UNITY_LIGHTMODEL_AMBIENT.rgb * texColor.rgb;
                
				fixed3 wardSpec = iBack * _LightColor0.rgb;
                // fixed shadow = SHADOW_ATTENUATION(i);
				// float3 diff = float3(_Color.rgb) * float3(_LightColor0.rgb) * max(0.0, LN) * shadow;

				fixed4 col = float4(ambientLight + texColor * _LightColor0.rgb * wardSpec, 1.0); // float4(1.0,1.0,1.0,1.0); // //tex2D(_MainTex, i.uv);

                return col;
            }
            ENDCG
        }
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
        
    }
}