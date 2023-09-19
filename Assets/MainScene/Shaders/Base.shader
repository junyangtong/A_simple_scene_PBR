
Shader "MyPBR/Base"
{
    Properties
    {
        _MainTex ("_MainTex", 2D) = "white" {}
        _Metallic ("_Metallic", 2D) = "white" {}
        _Roughness ("_Roughness", 2D) = "white" {}
		_Emission("_Emission", 2D) = "black" {}
		_NormaTex ("_NormaTex", 2D) =  "bump" {}
		_AlphaTex ("_AlphaTex", 2D) =  "white" {}
		_AoTex ("_AoTex", 2D) =  "white" {}
		[HDR]EmissCol("EmissCol", color) = (1.0,1.0,1.0,1.0)
        _MetallicInt ("_MetallicInt", Range(0, 1)) = 0.5
		_Tint("Tint", Color) = (1 ,1 ,1 ,1)
		_Smoothness("Smoothness", Range(0, 1)) = 0.5
		_LUT("PBRLUT", 2D) = "white" {}
		_SSSLUT("SSSLUT", 2D) = "white" {}
		_Cutoff("Cutoff",float) = 0.0
		_Transparent("Transparent",float) = 1.0
		_RefractionInt("_RefractionInt",float) = 0
		[MaterialToggle]_BTDFtoggle("_BTDFtoggle",int) = 0
		[Header(BTDF)]
		_btdfpow ("_btdfpow", Range(0, 10)) = 0.5
		_btdfscale("_btdfscale", Range(0, 10)) = 0.5
		_btdfDistortion("_btdfDistortion", Range(0, 1)) = 0.5
		_btdfCol("_btdfCol", Color) = (1 ,1 ,1 ,1)
		[Header(Option)]
        [Enum(UnityEngine.Rendering.BlendOp)]  _BlendOp  ("BlendOp", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", Float) = 0
        [Enum(Off, 0, On, 1)]_ZWriteMode ("ZWriteMode", float) = 1
        [Enum(UnityEngine.Rendering.CullMode)]_CullMode ("CullMode", float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)]_ZTestMode ("ZTestMode", Float) = 4
        [Enum(UnityEngine.Rendering.ColorWriteMask)]_ColorMask ("ColorMask", Float) = 15
    }

    SubShader
    {
        Tags {  
			"RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry" 
			//"RenderType"="Transparent"
            //"Queue"="Transparent"
			}
			LOD 100

        Pass
        {
			Tags {
				"LightMode" = "UniversalForward"
			}
			BlendOp [_BlendOp]
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWriteMode]
            ZTest [_ZTestMode]
            Cull [_CullMode]
            ColorMask [_ColorMask]

            HLSLPROGRAM
			#pragma target 4.6
            #pragma vertex vert
            #pragma fragment frag
			
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS       // 接受阴影
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE // 生成阴影坐标
            #pragma multi_compile_fragment _ _SHADOWS_SOFT    // 软阴影

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

			CBUFFER_START(UnityPerMaterial)
			float4 _Tint;
			float _Smoothness;
			float4 EmissCol;
            float _MetallicInt;
			float _Cutoff;
			float _Transparent;
			
			float _RefractionInt;
			bool _BTDFtoggle;
			float4 _btdfCol;
			float _btdfpow;
			float _btdfscale;
			float _btdfDistortion;
			CBUFFER_END
            TEXTURE2D (_MainTex);
			SAMPLER(sampler_MainTex);
			float4 _MainTex_ST;
            TEXTURE2D (_Metallic);
			SAMPLER(sampler_Metallic);
            TEXTURE2D (_Roughness);
            SAMPLER(sampler_Roughness);
			TEXTURE2D (_AlphaTex);
            SAMPLER(sampler_AlphaTex);
			TEXTURE2D (_AoTex);
            SAMPLER(sampler_AoTex);
            TEXTURE2D (_Emission);
			SAMPLER(sampler_Emission);
            TEXTURE2D (_NormaTex);
			SAMPLER(sampler_NormaTex);
			TEXTURE2D (_LUT);
			SAMPLER(sampler_LUT);
			TEXTURE2D (_SSSLUT);
			SAMPLER(sampler_SSSLUT);
			TEXTURE2D(_CameraOpaqueTexture);
			SAMPLER(sampler_CameraOpaqueTexture);
			
			
            struct appdata
            {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
				float4 tangent  : TANGENT;
            };

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float3 posWS : TEXCOORD2;
				float3 tDirWS : TEXCOORD3;
                float3 bDirWS : TEXCOORD4; 
                float3 nDirWS : TEXCOORD5; 
				float4 shadowCoord : TEXCOORD6;  //阴影坐标
				float4 scrPos : TEXCOORD7;  
			};

            v2f vert (appdata v)
            {
				v2f o;
				o.pos = TransformObjectToHClip(v.vertex);
				o.posWS = mul(unity_ObjectToWorld, v.vertex);
				o.uv = v.uv;
				o.normal = TransformObjectToWorldNormal(v.normal);
				o.normal = normalize(o.normal);
                o.tDirWS = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );//切线方向
                o.bDirWS = normalize(cross(o.normal, o.tDirWS) * v.tangent.w);                      //副切线方向
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
            }

			float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
			{
				return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}
			inline float3 FresnelTerm (float3 F0, half cosA)
			{
				half t = pow((1 - cosA),5);    // ala Schlick interpoliation
				return F0 + (1-F0) * t;
			} 
            float4 frag (v2f i) : SV_Target
            {
				Light light = GetMainLight();
				float3 nDirTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormaTex,sampler_NormaTex,i.uv * _MainTex_ST.xy + _MainTex_ST.zw)).rgb;
                float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.normal);                                //计算TBN矩阵
                float3 nDirWS = normalize(mul(nDirTS,TBN));
				i.normal = normalize(nDirWS);
				float3 lightDir = normalize(light.direction);
				float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
				float3 lightColor = light.color.rgb;
				float3 halfVector = normalize(lightDir + viewDir);  //半角向量
				
				float perceptualRoughness = 1 - _Smoothness;
                float var_Roughness = SAMPLE_TEXTURE2D(_Roughness,sampler_Roughness,i.uv * _MainTex_ST.xy + _MainTex_ST.zw).r;

				float roughness = perceptualRoughness * perceptualRoughness*var_Roughness;
				float squareRoughness = roughness * roughness;

				float nl = max(saturate(dot(i.normal, lightDir)), 0.000001);//防止除0
				float nv = max(saturate(dot(i.normal, viewDir)), 0.000001);
				float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
				float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);
				float nh = max(saturate(dot(i.normal, halfVector)), 0.000001);			

				//漫反射部分
                float3 Albedo = _Tint * SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv * _MainTex_ST.xy + _MainTex_ST.zw).rgb;
				//环境光
				float3 ambient = 0.03 * Albedo;
				//次表面散射
				float3 Sss = SAMPLE_TEXTURE2D(_SSSLUT,sampler_SSSLUT,float2(nl,0.5)).rgb;
				//透射
				float3 H = normalize(lightDir + i.normal * _btdfDistortion);
				float Denl = pow(saturate(dot(viewDir, -H)), _btdfpow)*_btdfscale;
				float3 btdf =  Denl;
				//环境光遮蔽
				float3 Ao = SAMPLE_TEXTURE2D(_AoTex,sampler_AoTex,i.uv * _MainTex_ST.xy + _MainTex_ST.zw).rgb;

				//镜面反射部分
				//D镜面分布函数
				float lerpSquareRoughness = pow(lerp(0.002, 1, roughness), 2);
				float D = lerpSquareRoughness / (pow((pow(nh, 2) * (lerpSquareRoughness - 1) + 1), 2) * PI);
				
				//几何遮蔽G
				float kInDirectLight = pow(squareRoughness + 1, 2) / 8;
				float kInIBL = pow(squareRoughness, 2) / 2;
				float GLeft = nl / lerp(nl, 1, kInDirectLight);
				float GRight = nv / lerp(nv, 1, kInDirectLight);
				float G = GLeft * GRight;

				//菲涅尔F
                float var_Metallic = SAMPLE_TEXTURE2D(_Metallic,sampler_Metallic,i.uv * _MainTex_ST.xy + _MainTex_ST.zw).r * _MetallicInt;
				float3 F0 = lerp(float3(0.04, 0.04, 0.04), Albedo, var_Metallic);
				float3 F = F0 + (1 - F0) * pow(1 - vh, 5.0);
				//镜面反射结果
				float3 SpecularResult = (D * G * F * 0.25)/(nv * nl);//配平系数=DGF/4×nv×nl
				
				//漫反射系数
				float3 kd = (1 - F)*(1 - var_Metallic);//kd为非金属反射系数，乘上（1-F）是为了保证能量守恒，乘一次(1-var_Metallic)是因为金属会更多的吸收折射光线导致漫反射消失
				
				//直接光照部分结果
				float3 specColor = SpecularResult * lightColor * nl * light.color.rgb * PI;
				float3 diffColor = kd * Albedo * lightColor * nl * Ao * Sss;
				float3 DirectLightResult = diffColor + specColor;

				
				//ibl部分
				float3 ambient_contrib = SampleSH(float4(i.normal, 1));//内置球谐光照计算相应的采样数据

				float3 iblDiffuse = max(float3(0, 0, 0), ambient + ambient_contrib);

				float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);//Unity的粗糙度和采样的mipmap等级关系mip = r(1.7 - 0.7r)
				float3 reflectVec = reflect(-viewDir, i.normal);

				half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;//用从0到1之间的mip_roughness函数换算出用于实际采样的mip层级，
				half4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0,reflectVec, mip); //根据粗糙度生成lod级别对贴图进行三线性采样
				float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);//使用DecodeHDR将颜色从HDR编码下解码

				float2 envBDRF = SAMPLE_TEXTURE2D(_LUT,sampler_LUT,float2(lerp(0, 0.99 ,nv), lerp(0, 0.99, roughness))).rg; // LUT采样
				
				float3 Flast = fresnelSchlickRoughness(max(nv, 0.0), F0, roughness);//新的菲涅尔系数
				float kdLast = (1 - Flast) * (1 - var_Metallic);
				
				float3 iblDiffuseResult = iblDiffuse * kdLast * Albedo;
				float3 iblSpecularResult = iblSpecular * (Flast * envBDRF.r + envBDRF.g);
				float3 IndirectResult = iblDiffuseResult + iblSpecularResult;

				//自发光
				float3 var_Emission = SAMPLE_TEXTURE2D(_Emission,sampler_Emission,i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
				float3 Emiss = var_Emission * EmissCol.rgb;
				//透明剪切
				float2 Alpha = SAMPLE_TEXTURE2D(_AlphaTex,sampler_AlphaTex,i.uv * _MainTex_ST.xy + _MainTex_ST.zw).rg; // LUT采样
				clip(Alpha-_Cutoff);
				//折射
				float2 screenPos= i.scrPos.xy / i.scrPos.w;
				float3 refraction = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenPos * lerp(0.7,1.0,nv)).rgb;

				// 计算阴影 
				i.shadowCoord = TransformWorldToShadowCoord(i.posWS); // 生成阴影坐标
                Light shadowLight = GetMainLight(i.shadowCoord);      // 计算阴影衰减
                float shadow = shadowLight.shadowAttenuation;         // 获取阴影
				float3 finalRGB = DirectLightResult * shadow + IndirectResult + Emiss + _BTDFtoggle * btdf * _btdfCol;
				//输出
				float4 result = float4(lerp(finalRGB, refraction , _RefractionInt * nv), _Transparent);
				return result;
				//return float4(refraction, 1);
            }

            ENDHLSL
        }
		UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
	FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}
