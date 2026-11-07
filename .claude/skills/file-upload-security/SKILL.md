---
name: file-upload-security
description: Secure file uploads and downloads in SaaS applications — type and size validation, safe storage names and locations, path traversal prevention, malware scanning hooks, image processing risks and tenant-scoped access to stored files.
---

# File upload security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Uploaded files can never execute on the server, overwrite other files, or be read by unauthorised users.
- Uploads cannot exhaust resources.

## Steps

1. **Find upload and download code**: Laravel `UploadedFile`/`store`/`storeAs`, `move_uploaded_file`,
   multer/busboy/formidable, Django `FileField`/`ImageField`, FastAPI `UploadFile`, pre-signed S3 uploads,
   avatar/import/attachment features, download/preview endpoints.
2. **Validate.** Allow-list extensions *and* verify content type from the file content (Laravel `mimes`/
   `mimetypes` rules, `file-type` in Node, `python-magic`); enforce max size at the web server
   (`client_max_body_size`, `LimitRequestBody`) and in the app; limit number of files.
3. **Name & path.** Generate the stored name server-side (`hashName()`, UUID); never use the client name in a
   path (Semgrep `sbs-php-upload-client-filename`); normalise and confine paths (`realpath` + prefix check);
   store the original name only as metadata, escaped on display.
4. **Location.** Store outside the web root or in object storage; never in a directory where the web server
   executes scripts (disable PHP execution in upload dirs on Apache/Nginx); private buckets by default.
5. **Serving.** Download through an authorized endpoint or short-lived signed URLs, scoped to the tenant;
   `Content-Disposition: attachment` for untrusted types; correct `Content-Type` + `X-Content-Type-Options: nosniff`;
   serve user content from a separate domain if HTML/SVG must be rendered.
6. **Dangerous formats.** SVG (scripts), HTML, XML (XXE), archives (zip slip, zip bombs), Office files with
   macros, images processed by ImageMagick/Ghostscript (keep patched, restrict policies), CSV injection in exports.
7. **Malware scanning.** For files shared between users, integrate a scanner (e.g. ClamAV) asynchronously and
   quarantine until clean — document if not available.
8. **Path traversal on download.** `sbs-js-path-traversal-sendfile`, `sbs-py-path-traversal-open` leads.

## Security rules

- Never upload real malware for testing; use the EICAR test string only in local environments.
- Do not widen allowed types to make an upload "work" without a risk assessment.

## Validation criteria

- [ ] Tests: `.php`/`.html`/`.svg` disguised uploads rejected or neutralised; oversize rejected; `../` names harmless.
- [ ] Other-tenant file download denied (test).
- [ ] Upload directory not executable (web server config reviewed).
