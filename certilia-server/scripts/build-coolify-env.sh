#!/usr/bin/env bash
# build-coolify-env.sh — offline generator Coolify ENV bundle-a za certilia-server.
#
# Workflow:
#   1) cp .coolify-secrets.env.example .coolify-secrets.env   (gitignored)
#   2) popuni CERTILIA_CLIENT_ID/SECRET + URL-ove u .coolify-secrets.env
#   3) ./scripts/build-coolify-env.sh
#        - generira JWT_SECRET/SESSION_SECRET (ako su prazni) i spremi ih u
#          .coolify-secrets.env (stabilno kroz restartove)
#        - mergea .env.example.coolify (defaulti) + .coolify-secrets.env (override)
#        - kopira finalni KEY=VALUE bundle u clipboard (pbcopy/xclip/wl-copy)
#   4) Coolify → certilia-server resource → Environment Variables → Bulk/Developer
#      view → Cmd+A → Paste → Save → Redeploy.
#
# Offline: koristi samo openssl + awk. Tajne se NE pišu na disk osim u
# .coolify-secrets.env (gitignored, tvoj lokalni store) i clipboard.
#
# Usage:
#   ./scripts/build-coolify-env.sh              # merge + clipboard
#   ./scripts/build-coolify-env.sh --preview    # + masked ispis na stdout
#   ./scripts/build-coolify-env.sh --no-copy    # bez clipboarda (samo preview)
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"   # → certilia-server/
BASE=".env.example.coolify"
SECRETS=".coolify-secrets.env"
EXAMPLE=".coolify-secrets.env.example"
COPY=true; PREVIEW=false

for a in "$@"; do case "$a" in
  --no-copy) COPY=false ;;
  --preview) PREVIEW=true ;;
  -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
  *) echo "Unknown arg: $a" >&2; exit 2 ;;
esac; done

command -v openssl >/dev/null || { echo "❌ openssl nije dostupan" >&2; exit 1; }
[ -f "$BASE" ] || { echo "❌ $BASE ne postoji (pokreni iz certilia-server/)" >&2; exit 1; }

if [ ! -f "$SECRETS" ]; then
  cp "$EXAMPLE" "$SECRETS"
  echo "⚠️  Kreiran $SECRETS iz primjera. Popuni CERTILIA_CLIENT_ID/SECRET +" >&2
  echo "    PRODUCTION_URL / CERTILIA_REDIRECT_URI / ALLOWED_ORIGINS pa ponovo pokreni." >&2
  exit 1
fi

# --- helpers ----------------------------------------------------------------
val() { grep -E "^$1=" "$SECRETS" 2>/dev/null | head -1 | cut -d= -f2- || true; }

# Generiraj secret ako je prazan/nepostojeći u $SECRETS i persistiraj ga tamo.
ensure_secret() {
  local k="$1" cur; cur="$(val "$k")"
  [ -n "$cur" ] && return 0
  local gen; gen="$(openssl rand -hex 64)"
  local tmp; tmp="$(mktemp)"
  if grep -qE "^$k=" "$SECRETS"; then
    awk -v k="$k" -v v="$gen" 'BEGIN{FS=OFS="="} $1==k{print k"="v; next} {print}' "$SECRETS" > "$tmp"
  else
    cat "$SECRETS" > "$tmp"; printf '%s=%s\n' "$k" "$gen" >> "$tmp"
  fi
  mv "$tmp" "$SECRETS"
  echo "🔑 generiran $k → spremljen u $SECRETS" >&2
}
ensure_secret JWT_SECRET
ensure_secret SESSION_SECRET

# --- validacija obaveznih ----------------------------------------------------
fail=0
require() {
  local k="$1" v; v="$(val "$k")"
  if [ -z "$v" ] || printf '%s' "$v" | grep -q 'your-proxy.example\|your-flutter-app.example'; then
    echo "❌ $k nije postavljen u $SECRETS (ili je placeholder)" >&2; fail=1
  fi
}
require CERTILIA_CLIENT_ID
require CERTILIA_CLIENT_SECRET
require CERTILIA_REDIRECT_URI
require PRODUCTION_URL
require ALLOWED_ORIGINS
[ "$fail" -eq 0 ] || { echo "Popuni nedostajuće u $SECRETS pa ponovi." >&2; exit 1; }

# --- merge: base defaulti + secrets override (zadnji pobjeđuje) -------------
# Izvuci KEY=VALUE iz oba (preskoči komentare/prazno); awk drži zadnju vrijednost
# po ključu, uz redoslijed prvog pojavljivanja.
MERGED="$(
  awk -F= '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /=/ {
      key=$1; sub(/^[[:space:]]+/,"",key); sub(/[[:space:]]+$/,"",key)
      val=substr($0, index($0,"=")+1)
      if (!(key in seen)) { order[++n]=key; seen[key]=1 }
      v[key]=val
    }
    END { for (i=1;i<=n;i++) print order[i]"="v[order[i]] }
  ' "$BASE" "$SECRETS"
)"

# --- output ------------------------------------------------------------------
if [ "$PREVIEW" = true ]; then
  echo "── ENV bundle (maskirano) ──" >&2
  printf '%s\n' "$MERGED" | awk -F= '
    { k=$1; v=substr($0,index($0,"=")+1)
      if (k ~ /SECRET|CLIENT_SECRET|JWT_SECRET|SESSION_SECRET/) {
        mv=(length(v)>8)?substr(v,1,4)"…"substr(v,length(v)-3):"****"; print k"="mv
      } else print k"="v
    }' >&2
fi

if [ "$COPY" = true ]; then
  if command -v pbcopy >/dev/null; then printf '%s\n' "$MERGED" | pbcopy
  elif command -v wl-copy >/dev/null; then printf '%s\n' "$MERGED" | wl-copy
  elif command -v xclip >/dev/null; then printf '%s\n' "$MERGED" | xclip -selection clipboard
  else echo "⚠️ nema pbcopy/wl-copy/xclip — koristi --preview --no-copy" >&2; exit 1
  fi
  echo "✅ ENV bundle u clipboardu ($(printf '%s\n' "$MERGED" | grep -c '=') varijabli). Paste u Coolify → Save → Redeploy." >&2
fi
