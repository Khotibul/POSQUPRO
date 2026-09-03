<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use Inertia\Inertia;

class SettingController extends Controller
{
    public function index()
    {
        $settings = Setting::latest()->get();

        return Inertia::render('Settings/Index', [
            'settings' => $settings,
        ]);
    }
}
