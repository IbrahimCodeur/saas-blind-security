{{-- Test cases for config/semgrep/rules/blade-saas.yaml --}}
<!-- ruleid: sbs-blade-unescaped-output -->
<div>{!! $user->bio !!}</div>
<!-- ruleid: sbs-blade-unescaped-output -->
<p>{!! nl2br($comment) !!}</p>
<!-- ruleid: sbs-blade-unescaped-output -->
<script type="application/ld+json">{!! json_encode($data) !!}</script>
<!-- ok: sbs-blade-unescaped-output -->
<p>{!! nl2br(e($comment)) !!}</p>
<!-- ok: sbs-blade-unescaped-output -->
<script type="application/ld+json">{!! json_encode($data, JSON_UNESCAPED_SLASHES | JSON_HEX_TAG) !!}</script>
<!-- ok: sbs-blade-unescaped-output -->
<form>{!! csrf_field() !!}</form>
<!-- ok: sbs-blade-unescaped-output -->
<p>{{ $user->bio }}</p>
