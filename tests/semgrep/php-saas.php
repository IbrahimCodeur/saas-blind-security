<?php
// INTENTIONALLY VULNERABLE TEST FILE for saas-blind-security Semgrep rules. Never deploy.
class InvoiceController
{
    public function show($request, $db, $conn)
    {
        $id = $request->input('id');
        // ruleid: sbs-php-sqli-string-building
        $rows = DB::select("SELECT * FROM invoices WHERE id = " . $id . " LIMIT 1");
        // ruleid: sbs-php-sqli-string-building
        $q->whereRaw("tenant_id = $id");
        // ruleid: sbs-php-sqli-string-building
        mysqli_query($conn, "SELECT * FROM users WHERE email = '" . $id . "'");
        // ok: sbs-php-sqli-string-building
        $rows = DB::select("SELECT * FROM invoices WHERE id = ?", [$id]);

        // ruleid: sbs-php-unserialize-user-input
        $prefs = unserialize($_COOKIE['prefs']);
        // ok: sbs-php-unserialize-user-input
        $prefs = json_decode($request->cookie('prefs'), true);

        // ruleid: sbs-php-weak-password-hash
        $hash = md5($password);
        // ok: sbs-php-weak-password-hash
        $hash = password_hash($password, PASSWORD_DEFAULT);

        // ruleid: sbs-laravel-mass-assignment-all
        $user = User::create($request->all());
        // ok: sbs-laravel-mass-assignment-all
        $user = User::create($request->validated());

        $file = $request->file('avatar');
        // ruleid: sbs-php-upload-client-filename
        $file->storeAs('avatars', $file->getClientOriginalName());
        // ok: sbs-php-upload-client-filename
        $file->storeAs('avatars', $file->hashName());

        $ch = curl_init('https://api.example.com');
        // ruleid: sbs-php-ssl-verification-disabled
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

        // ruleid: sbs-php-ssrf-user-url
        $body = file_get_contents($_GET['url']);
        // ruleid: sbs-php-ssrf-user-url
        $resp = Http::get($request->input('callback'));

        // ruleid: sbs-php-weak-random-token
        $resetToken = md5(uniqid());
        // ok: sbs-php-weak-random-token
        $resetToken = bin2hex(random_bytes(32));
    }
}

// ruleid: sbs-laravel-unguarded-model
class Team extends Model {
    protected $guarded = [];
}

// ok: sbs-laravel-unguarded-model
class Project extends Model {
    protected $fillable = ['name'];
}
