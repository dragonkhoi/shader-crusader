Shader "Custom/Reflective"
{
    Properties{
       _Cube("Reflection Map", Cube) = "" {}
       _Roughness("Roughness", Range(0.0, 10.0)) = 0.0
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            
            #include "AutoLight.cginc"
            
            samplerCUBE _Cube;
            float _Roughness;
            
            struct v2f {
                half3 worldRefl : TEXCOORD0;
                float4 pos : SV_POSITION;
                fixed3 ambient : COLOR1;
                SHADOW_COORDS(1)
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                // compute world space position of the vertex
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                // compute world space view direction
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                // world space normal
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                // world space reflection vector
                o.worldRefl = reflect(-worldViewDir, worldNormal);
                o.ambient = ShadeSH9(half4(worldNormal,1));
                // compute shadows data
                TRANSFER_SHADOW(o)
                return o;
            }
        
            fixed4 frag (v2f i) : SV_Target
            {
                // sample the default reflection cubemap, using the reflection vector
                half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, i.worldRefl, _Roughness);
                // decode cubemap data into actual color
                half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);
                // output it!
                fixed shadow = SHADOW_ATTENUATION(i);
                fixed4 c = 0;
                c.rgb = skyColor * shadow;
                return c;
            }
            ENDCG
        }
        
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
        
    }
    
}