package com.kodexsolutions.blockboom

import android.os.Bundle
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Google Play Games: starts the automatic sign-in.
        PlayGamesSdk.initialize(this)
        super.onCreate(savedInstanceState)
    }
}
