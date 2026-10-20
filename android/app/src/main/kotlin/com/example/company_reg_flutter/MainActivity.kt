package com.example.company_reg_flutter

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterFragmentActivity() {
    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }
}