package com.example.pusher;

import android.content.Intent;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.content.Context;
import android.media.MediaCodec;
import android.media.MediaFormat;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceHolder;

import com.example.pusher.VideoEncoder;
import com.example.pusher.model.VideoPacket;
import com.example.pusher.surface.SurfaceView;

import java.io.BufferedOutputStream;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.nio.ByteBuffer;

import java.io.FileOutputStream;

public class MainActivity extends AppCompatActivity {

    // video output dimension
    static final int OUTPUT_WIDTH = 640;
    static final int OUTPUT_HEIGHT = 480;

    VideoEncoder mEncoder;
//    VideoDecoder mDecoder;

    SurfaceView mEncoderSurfaceView;
//    android.view.SurfaceView mDecoderSurfaceView;

    FileOutputStream fs;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        File file = new File(this.getFilesDir(), "eugne5.h264");
        try {
            fs = new FileOutputStream(file);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }

        mEncoderSurfaceView = (SurfaceView) findViewById(R.id.encoder_surface);
        mEncoderSurfaceView.getHolder().addCallback(mEncoderCallback);

//        mDecoderSurfaceView = (android.view.SurfaceView) findViewById(R.id.decoder_surface);
//        mDecoderSurfaceView.getHolder().addCallback(mDecoderCallback);

        mEncoder = new MyEncoder();
//        mDecoder = new VideoDecoder();


        Button startButton = (Button) findViewById(R.id.button_start);
        startButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Log.i("Shit", "😃STAAAAAARING\n\n");
//                mEncoder.start();
            }
        });

    }



    private SurfaceHolder.Callback mEncoderCallback = new SurfaceHolder.Callback() {
        @Override
        public void surfaceCreated(SurfaceHolder surfaceHolder) {
            // surface is fully initialized on the activity
            mEncoderSurfaceView.startGLThread();
            mEncoder.start();
        }

        @Override
        public void surfaceChanged(SurfaceHolder surfaceHolder, int i, int i1, int i2) {

        }

        @Override
        public void surfaceDestroyed(SurfaceHolder surfaceHolder) {
            mEncoder.stop();
        }
    };

//    private SurfaceHolder.Callback mDecoderCallback = new SurfaceHolder.Callback() {
//        @Override
//        public void surfaceCreated(SurfaceHolder surfaceHolder) {
//            // surface is fully initialized on the activity
//            //mDecoderSurfaceView.startGLThread();
//            mDecoder.start();
//        }
//
//        @Override
//        public void surfaceChanged(SurfaceHolder surfaceHolder, int i, int i1, int i2) {
//
//        }
//
//        @Override
//        public void surfaceDestroyed(SurfaceHolder surfaceHolder) {
//            mDecoder.stop();
//        }
//    };

    class MyEncoder extends VideoEncoder {

        byte[] mBuffer = new byte[0];

        public MyEncoder() {
            super(mEncoderSurfaceView, OUTPUT_WIDTH, OUTPUT_HEIGHT);
        }

        @Override
        protected void onEncodedSample(MediaCodec.BufferInfo info, ByteBuffer data) {

            // save to file
            try {
                fs.write(mBuffer);
            } catch (IOException e) {
                e.printStackTrace();
            }

            // Here we could have just used ByteBuffer, but in real life case we might need to
            // send sample over network, etc. This requires byte[]
            if (mBuffer.length < info.size) {
                mBuffer = new byte[info.size];
            }
            data.position(info.offset);
            data.limit(info.offset + info.size);
            data.get(mBuffer, 0, info.size);

            Log.d("ENCODER_FLAG", String.valueOf(info.flags));

            if ((info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == MediaCodec.BUFFER_FLAG_CODEC_CONFIG) {
                // this is the first and only config sample, which contains information about codec
                // like H.264, that let's configure the decoder

                VideoPacket.StreamSettings streamSettings = VideoPacket.getStreamSettings(mBuffer);

//                mDecoder.configure(mDecoderSurfaceView.getHolder().getSurface(),
//                        OUTPUT_WIDTH,
//                        OUTPUT_HEIGHT,
//                        streamSettings.sps, streamSettings.pps);
            } else {




                // pass byte[] to decoder's queue to render asap
//                mDecoder.decodeSample(mBuffer,
//                        0,
//                        info.size,
//                        info.presentationTimeUs,
//                        info.flags);


            }
        }
    }
}
