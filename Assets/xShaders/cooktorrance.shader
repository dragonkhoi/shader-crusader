// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//Cook Torrance CG shader with spec map


Shader "CG Shaders/Alternative Lighting/Cook Torrance"
{
	Properties
	{
		_diffuseColor("Diffuse Color", Color) = (1,1,1,1)
		_diffuseMap("Diffuse", 2D) = "white" {}
		_specularColor("Specular Color", Color) = (1,1,1,1)
		_normalMap("Normal / Specular (A)", 2D) = "bump" {}
		_roughness("Roughness", Range(0.0, 1.0)) = 0
		_schlick("Frensel Multiplier", Range(0.0, 1.0)) = 0
		_schlick (" ", Float) = 1
	}
	SubShader
	{
		Pass
		{
			Tags { "LightMode" = "ForwardBase" } 
            
			CGPROGRAM
			
			#pragma vertex vShader
			#pragma fragment pShader
			#include "UnityCG.cginc"
			#pragma multi_compile_fwdbase
			#pragma target 3.0
			
			uniform fixed3 _diffuseColor;
			uniform sampler2D _diffuseMap;
			uniform half4 _diffuseMap_ST;			
			uniform fixed4 _LightColor0; 
			uniform half _FrenselPower;
			uniform fixed4 _rimColor;
			uniform half _specularPower;
			uniform fixed3 _specularColor;
			uniform sampler2D _normalMap;
			uniform half4 _normalMap_ST;	
			uniform fixed _roughness;
			uniform fixed _schlick;
			
			struct app2vert {
				float4 vertex 	: 	POSITION;
				fixed2 texCoord : 	TEXCOORD0;
				fixed4 normal 	:	NORMAL;
				fixed4 tangent : TANGENT;
				
			};
			struct vert2Pixel
			{
				float4 pos 						: 	SV_POSITION;
				fixed2 uvs						:	TEXCOORD0;
				fixed3 normalDir						:	TEXCOORD1;	
				fixed3 binormalDir					:	TEXCOORD2;	
				fixed3 tangentDir					:	TEXCOORD3;	
				half3 posWorld						:	TEXCOORD4;	
				fixed3 viewDir						:	TEXCOORD5;
			};
			
			fixed lambert(fixed3 N, fixed3 L)
			{
				return saturate(dot(N, L));
			}
			
			fixed phong(fixed3 R, fixed3 L)
			{
				return pow(saturate(dot(R, L)), _specularPower);
			}
			
			fixed cookTorrance( fixed3 V, fixed3 N, fixed3 L)
			{
				//half vector like blinn
				fixed3 halfV = normalize(L+V);
				//I don't saturate any of these dot products. It seems to cause issues
				//lambertian falloff
				fixed ndotL = dot(N, L);
				//blinn falloff
				fixed ndotH = dot(N, halfV);
				//frensel falloff
				fixed ndotV = dot(N, V);
				//half vector falloff
				fixed hdotV = dot(halfV, V);
				//roughness squared
				//I hack this slightly to avoid a perfectly smooth surface
				//standard is calculated as:
				//fixed roughSq = _roughness * _roughness;
				//instead i use:
				fixed roughSq = _roughness + 0.01;
				roughSq = saturate(roughSq* roughSq);
				//calculate self shadowing
				fixed shadowM = 2*ndotH;				
				//light blocked by a nieghboring facet towards the view vector
				fixed shadowV = (shadowM *ndotV) / hdotV;
				//light blocked by a nieghboring facet towards the light vector
				fixed shadowL = (shadowM *ndotL ) / hdotV;
				//full self shadowing
				fixed shadow = min(1.0, min(shadowV,shadowL) );
				
				//calculate the roughness
				// requires ndotH to the 2nd and 4th power so we precalculate
				fixed ndotHSq = ndotH * ndotH;
				fixed ndotHQuad = ndotHSq*ndotHSq;
				fixed roughness = 1.0/ (4.0 * roughSq * ndotHQuad);				
				roughness *= exp((ndotHSq - 1)/(ndotHSq * roughSq));
				
				//calculate the frensel
				//using schlick's approximation as full Cook-Toor requires a few square roots and a lot more math
				//schlick's approximation requires raising to a power of 5 so i precalculate
				fixed frensel = 1- hdotV;
				frensel = frensel*frensel*frensel*frensel*frensel;
				frensel*= (1- _schlick);
				frensel+=  _schlick;
				
				
				fixed specular = frensel * shadow * roughness;
				specular /= (ndotV * ndotL);			
				
				return saturate(specular);
			}
			vert2Pixel vShader(app2vert IN)
			{
				vert2Pixel OUT;
				float4x4 WorldViewProjection = UNITY_MATRIX_MVP;
				float4x4 WorldInverseTranspose = unity_WorldToObject; 
				float4x4 World = unity_ObjectToWorld;
							
				OUT.pos = mul(WorldViewProjection, IN.vertex);
				OUT.uvs = IN.texCoord;					
				OUT.normalDir = normalize(mul(IN.normal, WorldInverseTranspose).xyz);
				OUT.tangentDir = normalize(mul(IN.tangent, WorldInverseTranspose).xyz);
				OUT.binormalDir = normalize(cross(OUT.normalDir, OUT.tangentDir)); 
				OUT.posWorld = mul(World, IN.vertex).xyz;
				OUT.viewDir = normalize(  _WorldSpaceCameraPos -OUT.posWorld );

				//no vertex lights
				
				return OUT;
			}
			
			fixed4 pShader(vert2Pixel IN): COLOR
			{
				half2 normalUVs = TRANSFORM_TEX(IN.uvs, _normalMap);
				fixed4 normalD = tex2D(_normalMap, normalUVs);
				normalD.xyz = (normalD.xyz * 2) - 1;
			
				//half3 normalDir = half3(2.0 * normalSample.xy - float2(1.0), 0.0);
				//deriving the z component
				//normalDir.z = sqrt(1.0 - dot(normalDir, normalDir));
               // alternatively you can approximate deriving the z component without sqrt like so:  
				//normalDir.z = 1.0 - 0.5 * dot(normalDir, normalDir);
				
				fixed3 normalDir = normalD.xyz;	
				fixed specMap = normalD.w;
				normalDir = normalize((normalDir.x * IN.tangentDir) + (normalDir.y * IN.binormalDir) + (normalDir.z * IN.normalDir));
	
				fixed3 ambientL =  UNITY_LIGHTMODEL_AMBIENT.xyz;
	
				//Main Light calculation - includes directional lights
				half3 pixelToLightSource =_WorldSpaceLightPos0.xyz - (IN.posWorld*_WorldSpaceLightPos0.w);
				fixed attenuation  = lerp(1.0, 1.0/ length(pixelToLightSource), _WorldSpaceLightPos0.w);				
				fixed3 lightDirection = normalize(pixelToLightSource);
				fixed diffuseL = lambert(normalDir, lightDirection);				
				
				
				fixed3 diffuse = _LightColor0.xyz * diffuseL* attenuation;				
				diffuse = saturate( ambientL + diffuse);
		
				fixed specularHighlight = diffuseL* cookTorrance(IN.viewDir , normalDir,lightDirection);
				
				fixed4 outColor;							
				half2 diffuseUVs = TRANSFORM_TEX(IN.uvs, _diffuseMap);
				fixed4 texSample = tex2D(_diffuseMap, diffuseUVs);
				//modified this slightly. Diffuse color is added to spec and then multiplied by diffuse light
				//This incorporates light attenuation/color and allows diffuse color to effect specular
				fixed3 diffuseC =  texSample.xyz * _diffuseColor.xyz;
				fixed3 specular = (specularHighlight * _specularColor * specMap);
				outColor = fixed4( diffuse * (specular + diffuseC) ,1.0);
				return outColor;
			}
			
			ENDCG
		}	
		
			//the second pass for additional lights
		Pass
		{
			Tags { "LightMode" = "ForwardAdd" } 
			Blend One One 
			
			CGPROGRAM
			#pragma vertex vShader
			#pragma fragment pShader
			#include "UnityCG.cginc"
			#pragma target 3.0
			
			uniform fixed3 _diffuseColor;
			uniform sampler2D _diffuseMap;
			uniform half4 _diffuseMap_ST;
			uniform fixed4 _LightColor0; 		
			uniform half _specularPower;
			uniform fixed3 _specularColor;
			uniform sampler2D _normalMap;
			uniform half4 _normalMap_ST;	
			uniform fixed _roughness;
			uniform fixed _schlick;
			
			
			
			struct app2vert {
				float4 vertex 	: 	POSITION;
				fixed2 texCoord : 	TEXCOORD0;
				fixed4 normal 	:	NORMAL;
				fixed4 tangent : TANGENT;
			};
			struct vert2Pixel
			{
				float4 pos 						: 	SV_POSITION;
				fixed2 uvs						:	TEXCOORD0;	
				fixed3 normalDir						:	TEXCOORD1;	
				fixed3 binormalDir					:	TEXCOORD2;	
				fixed3 tangentDir					:	TEXCOORD3;	
				half3 posWorld						:	TEXCOORD4;	
				fixed3 viewDir						:	TEXCOORD5;
			};
			
			fixed lambert(fixed3 N, fixed3 L)
			{
				return saturate(dot(N, L));
			}			
			fixed phong(fixed3 R, fixed3 L)
			{
				return pow(saturate(dot(R, L)), _specularPower);
			}
			fixed cookTorrance( fixed3 V, fixed3 N, fixed3 L)
			{
				//half vector like blinn
				fixed3 halfV = normalize(L+V);
				//I don't saturate any of these dot products. It seems to cause issues
				//lambertian falloff
				fixed ndotL = dot(N, L);
				//blinn falloff
				fixed ndotH = dot(N, halfV);
				//frensel falloff
				fixed ndotV = dot(N, V);
				//half vector falloff
				fixed hdotV = dot(halfV, V);
				//roughness squared
				//I hack this slightly to avoid a perfectly smooth surface
				//standard is calculated as:
				//fixed roughSq = _roughness * _roughness;
				//instead i use:
				fixed roughSq = _roughness + 0.01;
				roughSq = saturate(roughSq* roughSq);
				//calculate self shadowing
				fixed shadowM = 2*ndotH;				
				//light blocked by a nieghboring facet towards the view vector
				fixed shadowV = (shadowM *ndotV) / hdotV;
				//light blocked by a nieghboring facet towards the light vector
				fixed shadowL = (shadowM *ndotL ) / hdotV;
				//full self shadowing
				fixed shadow = min(1.0, min(shadowV,shadowL) );
				
				//calculate the roughness
				// requires ndotH to the 2nd and 4th power so we precalculate
				fixed ndotHSq = ndotH * ndotH;
				fixed ndotHQuad = ndotHSq*ndotHSq;
				fixed roughness = 1.0/ (4.0 * roughSq * ndotHQuad);				
				roughness *= exp((ndotHSq - 1)/(ndotHSq * roughSq));
				
				//calculate the frensel
				//using schlick's approximation as full Cook-Toor requires a few square roots and a lot more math
				//schlick's approximation requires raising to a power of 5 so i precalculate
				fixed frensel = 1- hdotV;
				frensel = frensel*frensel*frensel*frensel*frensel;
				frensel*= (1- _schlick);
				frensel+=  _schlick;
				
				
				fixed specular = frensel * shadow * roughness;
				specular /= (ndotV * ndotL);			
				
				return saturate(specular);
			}
			
			vert2Pixel vShader(app2vert IN)
			{
				vert2Pixel OUT;
				float4x4 WorldViewProjection = UNITY_MATRIX_MVP;
				float4x4 WorldInverseTranspose = unity_WorldToObject; 
				float4x4 World = unity_ObjectToWorld;
				
				OUT.pos = mul(WorldViewProjection, IN.vertex);
				OUT.uvs = IN.texCoord;	
				
				OUT.normalDir = normalize(mul(IN.normal, WorldInverseTranspose).xyz);
				OUT.tangentDir = normalize(mul(IN.tangent, WorldInverseTranspose).xyz);
				OUT.binormalDir = normalize(cross(OUT.normalDir, OUT.tangentDir)); 
				OUT.posWorld = mul(World, IN.vertex).xyz;
				OUT.viewDir = normalize(  _WorldSpaceCameraPos -OUT.posWorld );
				return OUT;
			}
			fixed4 pShader(vert2Pixel IN): COLOR
			{
				half2 normalUVs = TRANSFORM_TEX(IN.uvs, _normalMap);
				fixed4 normalD = tex2D(_normalMap, normalUVs);
				normalD.xyz = (normalD.xyz * 2) - 1;
				
				//half3 normalDir = half3(2.0 * normalSample.xy - float2(1.0), 0.0);
				//deriving the z component
				//normalDir.z = sqrt(1.0 - dot(normalDir, normalDir));
               // alternatively you can approximate deriving the z component without sqrt like so: 
				//normalDir.z = 1.0 - 0.5 * dot(normalDir, normalDir);
				
				fixed3 normalDir = normalD.xyz;	
				fixed specMap = normalD.w;
				normalDir = normalize((normalDir.x * IN.tangentDir) + (normalDir.y * IN.binormalDir) + (normalDir.z * IN.normalDir));
						
				//Fill lights
				half3 pixelToLightSource = _WorldSpaceLightPos0.xyz- (IN.posWorld*_WorldSpaceLightPos0.w);
				fixed attenuation  = lerp(1.0, 1.0/ length(pixelToLightSource), _WorldSpaceLightPos0.w);				
				fixed3 lightDirection = normalize(pixelToLightSource);
				
				fixed diffuseL = lambert(normalDir, lightDirection);				
				fixed3 diffuse = _LightColor0.xyz * diffuseL * attenuation;
			
				//specular highlight
				fixed specularHighlight = diffuseL* cookTorrance(IN.viewDir , normalDir,lightDirection);
				
				fixed4 outColor;							
				half2 diffuseUVs = TRANSFORM_TEX(IN.uvs, _diffuseMap);
				fixed4 texSample = tex2D(_diffuseMap, diffuseUVs);	
				//modified this slightly. Diffuse color is added to spec and then multiplied by diffuse light
				//This incorporates light attenuation/color and allows diffuse color to effect specular
				fixed3 diffuseC =  texSample.xyz * _diffuseColor.xyz;
				fixed3 specular = specularHighlight * _specularColor * specMap;
				outColor = fixed4( diffuse * (specular + diffuseC),1.0);
				return outColor;
			}
			
			ENDCG
		}	
		
		
	}
}