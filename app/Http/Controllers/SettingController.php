<?php

namespace App\Http\Controllers;

use App\Models\PaymentMethod;
use App\Models\Tax;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class SettingController extends Controller
{
    public function index()
    {
        // Load settings from Java columns (setting_key/setting_value/setting_group)
        $settings = DB::table('settings')
            ->whereNotNull('setting_key')
            ->get()
            ->map(fn ($s) => [
                'id' => $s->id,
                'key' => $s->setting_key,
                'value' => $s->setting_value,
                'group' => $s->setting_group,
            ]);

        return Inertia::render('Settings/Index', [
            'settings' => $settings,
            'taxes' => Tax::orderBy('name')->get(),
            'paymentMethods' => PaymentMethod::orderBy('name')->get(),
            'branches' => DB::table('branches')->where('active', 1)->get(),
        ]);
    }

    public function updateGroup(Request $request)
    {
        $data = $request->validate([
            'group' => ['required', 'string'],
            'settings' => ['required', 'array'],
            'settings.*.key' => ['required', 'string'],
            'settings.*.value' => ['nullable', 'string'],
        ]);

        foreach ($data['settings'] as $item) {
            DB::table('settings')
                ->where('setting_key', $item['key'])
                ->update(['setting_value' => $item['value'] ?? '', 'updated_at' => now()]);
        }

        return redirect()->back()->with('success', 'Pengaturan '.$data['group'].' disimpan!');
    }

    public function storeTax(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'rate' => ['required', 'numeric', 'min:0', 'max:100'],
        ]);

        Tax::create($data + ['is_active' => true]);

        return redirect()->back()->with('success', 'Pajak ditambahkan!');
    }

    public function updateTax(Request $request, string $id)
    {
        $tax = Tax::findOrFail($id);
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'rate' => ['sometimes', 'numeric', 'min:0', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $tax->update($data);

        return redirect()->back()->with('success', 'Pajak diperbarui!');
    }

    public function destroyTax(string $id)
    {
        Tax::findOrFail($id)->delete();

        return redirect()->back()->with('success', 'Pajak dihapus!');
    }

    public function updatePaymentMethod(Request $request, string $id)
    {
        $pm = PaymentMethod::findOrFail($id);
        $data = $request->validate([
            'active' => ['required', 'boolean'],
        ]);

        $pm->update($data);

        return redirect()->back()->with('success', 'Metode pembayaran diperbarui!');
    }
}
