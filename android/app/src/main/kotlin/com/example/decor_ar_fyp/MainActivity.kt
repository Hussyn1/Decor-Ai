package com.example.decor_ar_fyp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ar_app/ar_core"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "isCloudAnchorSupported" -> result.success(true)
                "hostCloudAnchor" -> {
                    val anchorId = call.argument<String>("anchorId")
                    // In a full implementation with API Key:
                    // val cloudAnchor = session.hostCloudAnchor(localAnchor)
                    // result.success(cloudAnchor.cloudAnchorId)
                    result.success("cloud_anchor_pending_api_key")
                }
                "resolveCloudAnchor" -> {
                    val cloudAnchorId = call.argument<String>("cloudAnchorId")
                    // val cloudAnchor = session.resolveCloudAnchor(cloudAnchorId)
                    // result.success(true)
                    result.success(false) 
                }
                "enableOcclusion" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    // In a full implementation, we would access the ARCore Session here
                    // e.g., session.configure(session.config.apply { depthMode = Config.DepthMode.AUTOMATIC })
                    result.success(null)
                }
                "enableLightEstimation" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    // e.g., session.configure(session.config.apply { lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR })
                    result.success(null)
                }
                "updateNodeTexture" -> {
                    val nodeName = call.argument<String>("nodeName")
                    val textureUrl = call.argument<String>("textureUrl")
                    // In a full implementation, we would download the texture and apply it to the node's material
                    // node.modelInstance.material.setTexture(...)
                    result.success(null)
                }
                "isDepthMeshSupported" -> {
                    // result.success(session.isDepthModeSupported(Config.DepthMode.AUTOMATIC))
                    result.success(true) 
                }
                "enableDepthMesh" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    // session.configure(session.config.apply { 
                    //    depthMode = if(enable) Config.DepthMode.AUTOMATIC else Config.DepthMode.DISABLED 
                    // })
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
