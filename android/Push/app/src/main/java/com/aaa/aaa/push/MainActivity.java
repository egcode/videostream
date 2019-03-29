package com.aaa.aaa.push;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.concurrent.ArrayBlockingQueue;

import android.Manifest;
import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.ImageFormat;
import android.hardware.Camera;
import android.hardware.Camera.Parameters;
import android.hardware.Camera.PreviewCallback;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.os.Build;
import android.os.Bundle;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

public class MainActivity extends Activity  implements SurfaceHolder.Callback,PreviewCallback{

    private SurfaceView surfaceview;

    private SurfaceHolder surfaceHolder;

    private Camera camera;

    private Parameters parameters;

    int width = 1280;

    int height = 720;

    int framerate = 30;

    int biterate = 8500*1000;

    private static int yuvqueuesize = 10;

    public static ArrayBlockingQueue<byte[]> YUVQueue = new ArrayBlockingQueue<byte[]>(yuvqueuesize);

    private AvcEncoder avcCodec;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        surfaceview = (SurfaceView)findViewById(R.id.surfaceview);
        surfaceHolder = surfaceview.getHolder();
        surfaceHolder.addCallback(this);
        SupportAvcCodec();

        //If authorisation not granted for camera
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.CAMERA}, 50);
        } else {
//            this.startCamera();
        }

    }


    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        camera = getBackCamera();
        startcamera(camera);
        avcCodec = new AvcEncoder(width,height,framerate,biterate, this);
        avcCodec.StartEncoderThread();

    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {

    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        if (null != camera) {
            camera.setPreviewCallback(null);
            camera.stopPreview();
            camera.release();
            camera = null;
            avcCodec.StopThread();
        }
    }


    @Override
    public void onPreviewFrame(byte[] data, android.hardware.Camera camera) {
        // TODO Auto-generated method stub
        putYUVData(data,data.length);
    }

    public void putYUVData(byte[] buffer, int length) {
        if (YUVQueue.size() >= 10) {
            YUVQueue.poll();
        }
        YUVQueue.add(buffer);
    }

    @SuppressLint("NewApi")
    private boolean SupportAvcCodec(){
        if(Build.VERSION.SDK_INT>=18){
            for(int j = MediaCodecList.getCodecCount() - 1; j >= 0; j--){
                MediaCodecInfo codecInfo = MediaCodecList.getCodecInfoAt(j);

                String[] types = codecInfo.getSupportedTypes();
                for (int i = 0; i < types.length; i++) {
                    if (types[i].equalsIgnoreCase("video/avc")) {
                        return true;
                    }
                }
            }
        }
        return false;
    }


    private void startcamera(Camera mCamera){
        if(mCamera != null){
            try {
                mCamera.setPreviewCallback(this);
                mCamera.setDisplayOrientation(90);
                if(parameters == null){
                    parameters = mCamera.getParameters();
                }
                parameters = mCamera.getParameters();
                parameters.setPreviewFormat(ImageFormat.NV21);
                parameters.setPreviewSize(width, height);
                parameters.setFocusMode(parameters.FOCUS_MODE_AUTO);
                parameters.setFocusMode(parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
                mCamera.setParameters(parameters);
                mCamera.setPreviewDisplay(surfaceHolder);
                mCamera.startPreview();

            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    @TargetApi(9)
    private Camera getBackCamera() {
        Camera c = null;
        try {
            c = Camera.open(0); // attempt to get a Camera instance
        } catch (Exception e) {
            e.printStackTrace();
        }
        return c; // returns null if camera is unavailable
    }


}
