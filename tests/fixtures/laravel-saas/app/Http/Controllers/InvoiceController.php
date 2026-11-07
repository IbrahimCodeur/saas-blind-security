<?php
// INTENTIONALLY VULNERABLE FIXTURE. Never deploy.
namespace App\Http\Controllers;

class InvoiceController extends Controller
{
    public function show($request)
    {
        $id = $request->input('id');
        return DB::select("SELECT * FROM invoices WHERE id = " . $id . " AND tenant_id = 1");
    }

    public function store($request)
    {
        return Invoice::create($request->all());
    }
}
