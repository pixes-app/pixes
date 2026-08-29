package com.github.wgh136.pixes

import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import android.view.WindowManager

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        //获取http代理
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pixes/proxy"
        ).setMethodCallHandler { _, res ->
            res.success(getProxy())
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pixes/screen_awake"
        ).setMethodCallHandler { call, res ->
            if (call.method != "setKeepScreenOn") {
                res.notImplemented()
                return@setMethodCallHandler
            }
            val enabled = call.arguments as? Boolean ?: false
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            res.success(null)
        }
    }

    private fun getProxy(): String{
        val host = System.getProperty("http.proxyHost")
        val port = System.getProperty("http.proxyPort")
        return if(host!=null&&port!=null){
            "$host:$port"
        }else{
            "No Proxy"
        }
    }
}
