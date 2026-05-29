<script lang="ts">
  import { donation } from '$lib/stores/donation.svelte';

  const PIX = '95c1adaf-d8ee-4498-b7af-3a810ae30b59';
  const PAYPAL = 'hasen.borges@gmail.com';

  let showKeyField = $state(false);
  let keyInput = $state('');
  let keyError = $state(false);
  let validating = $state(false);

  let copiedPix = $state(false);
  let copiedPayPal = $state(false);

  async function copyText(text: string, which: 'pix' | 'paypal') {
    try {
      await navigator.clipboard.writeText(text);
      if (which === 'pix') {
        copiedPix = true;
        setTimeout(() => (copiedPix = false), 2000);
      } else {
        copiedPayPal = true;
        setTimeout(() => (copiedPayPal = false), 2000);
      }
    } catch {
      /* ignore */
    }
  }

  async function submit() {
    if (!keyInput.trim() || validating) return;
    validating = true;
    keyError = false;
    const ok = await donation.submitKey(keyInput);
    validating = false;
    if (!ok) keyError = true;
  }

  function onKeyInput() {
    keyError = false;
  }
</script>

{#if donation.showPopup}
  <div class="overlay" role="presentation">
    <div class="popup" role="dialog" aria-labelledby="dp-title">
      <header>
        <div class="badge">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
            <path d="M12 21s-7-4.35-9.5-9.5C.5 7 4 3 7 3c2 0 3.5 1 5 3 1.5-2 3-3 5-3 3 0 6.5 4 4.5 8.5C19 16.65 12 21 12 21z" />
          </svg>
        </div>
        <div>
          <h2 id="dp-title">Apoie o Lume</h2>
          <p class="sub">Mantenha o projeto livre e em desenvolvimento</p>
        </div>
      </header>

      <div class="body">
        <p class="intro">
          O Lume é livre. Se ele te ajudou, considere uma doação — mesmo simbólica.
          Cada apoio paga as horas que não vão pra trabalho remunerado.
        </p>

        <div class="options">
          <article class="opt pix">
            <span class="opt-icon">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" />
                <rect x="3" y="14" width="7" height="7" /><rect x="14" y="14" width="7" height="7" />
              </svg>
            </span>
            <div class="opt-body">
              <div class="opt-head">
                <b>PIX</b>
                <span class="badge-pill">Brasil</span>
              </div>
              <code class="opt-value">{PIX}</code>
            </div>
            <button class="copy" class:copied={copiedPix} onclick={() => copyText(PIX, 'pix')}>
              {copiedPix ? '✓ Copiado' : 'Copiar'}
            </button>
          </article>

          <article class="opt paypal">
            <span class="opt-icon">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="2" y="5" width="20" height="14" rx="2" /><path d="M2 10h20" />
              </svg>
            </span>
            <div class="opt-body">
              <div class="opt-head">
                <b>PayPal</b>
                <span class="badge-pill blue">Internacional</span>
              </div>
              <code class="opt-value">{PAYPAL}</code>
            </div>
            <button class="copy" class:copied={copiedPayPal} onclick={() => copyText(PAYPAL, 'paypal')}>
              {copiedPayPal ? '✓ Copiado' : 'Copiar'}
            </button>
          </article>
        </div>

        {#if !showKeyField}
          <button class="link" onclick={() => (showKeyField = true)}>
            Já doei — tenho uma chave de ativação ↗
          </button>
        {:else}
          <div class="key-section">
            <h3>Chave de ativação</h3>
            <p>Cole a chave que você recebeu por e-mail após doar:</p>
            <div class="key-row">
              <input
                type="text"
                bind:value={keyInput}
                oninput={onKeyInput}
                placeholder="LUME-DONOR-XXXX-XXXX-XXXX-XXXX"
                class:error={keyError}
                disabled={validating}
              />
              <button class="validate" disabled={!keyInput.trim() || validating} onclick={submit}>
                {validating ? 'Validando…' : 'Ativar'}
              </button>
            </div>
            {#if keyError}
              <p class="err">Chave inválida. Verifique se digitou corretamente.</p>
            {/if}
          </div>
        {/if}
      </div>

      <footer>
        <button class="ghost" onclick={() => donation.disable()}>Não lembrar mais</button>
        <button class="primary" onclick={() => donation.remindLater()}>Lembrar em 30 dias</button>
      </footer>
    </div>
  </div>
{/if}

<style>
  .overlay {
    position: fixed; inset: 0;
    background: rgba(7, 7, 18, 0.72);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    z-index: 1000;
    display: grid; place-items: center;
    animation: fade-in 180ms var(--ease-out);
  }
  @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }

  .popup {
    width: 480px;
    max-width: 92vw;
    max-height: 88vh;
    overflow: auto;
    background: linear-gradient(180deg, #100627 0%, #07071A 100%);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 18px;
    box-shadow: 0 32px 80px rgba(0, 0, 0, 0.7);
    display: flex; flex-direction: column;
    animation: pop-in 240ms var(--ease-out);
  }
  @keyframes pop-in {
    from { opacity: 0; transform: translateY(8px) scale(0.97); }
    to   { opacity: 1; transform: translateY(0)   scale(1);    }
  }

  header {
    display: flex; align-items: center; gap: 14px;
    padding: 20px 22px 18px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .badge {
    width: 40px; height: 40px;
    border-radius: 10px;
    background: linear-gradient(135deg, #FF6B9D, #C84B72);
    color: #fff;
    display: grid; place-items: center;
    box-shadow: 0 6px 18px rgba(255, 107, 157, 0.32);
  }
  h2 { font-size: 16px; font-weight: 700; letter-spacing: -0.01em; }
  .sub { font-size: 11.5px; color: var(--text-secondary); margin-top: 2px; }

  .body {
    padding: 18px 22px 14px;
    display: flex; flex-direction: column; gap: 16px;
  }
  .intro {
    font-size: 12.5px;
    color: var(--text-secondary);
    line-height: 1.6;
  }

  .options { display: flex; flex-direction: column; gap: 8px; }
  .opt {
    display: grid;
    grid-template-columns: auto 1fr auto;
    gap: 12px;
    align-items: center;
    padding: 11px 13px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.035);
    border: 1px solid var(--border);
  }
  .opt-icon {
    width: 30px; height: 30px;
    border-radius: 8px;
    display: grid; place-items: center;
  }
  .pix .opt-icon { background: rgba(0, 201, 167, 0.14); color: #00C9A7; }
  .paypal .opt-icon { background: rgba(77, 143, 255, 0.14); color: #4D8FFF; }
  .opt-head { display: flex; align-items: center; gap: 7px; margin-bottom: 2px; }
  .opt b { font-size: 13px; color: #fff; }
  .badge-pill {
    font-size: 9px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase;
    color: #00C9A7; background: rgba(0, 201, 167, 0.15);
    padding: 2px 7px; border-radius: 999px;
  }
  .badge-pill.blue { color: #4D8FFF; background: rgba(77, 143, 255, 0.15); }
  .opt-value {
    font-family: var(--font-mono);
    font-size: 11px;
    color: rgba(255, 255, 255, 0.62);
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .copy {
    padding: 5px 11px;
    border-radius: 999px;
    font-size: 11px; font-weight: 700;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid var(--border);
    color: #fff;
  }
  .copy:hover { background: rgba(255, 255, 255, 0.10); }
  .copy.copied { color: var(--success); background: color-mix(in srgb, var(--success) 16%, transparent); border-color: color-mix(in srgb, var(--success) 32%, transparent); }

  .link {
    align-self: flex-start;
    color: var(--accent);
    font-size: 12px; font-weight: 600;
    padding: 2px 0;
  }
  .link:hover { text-decoration: underline; }

  .key-section {
    display: flex; flex-direction: column; gap: 10px;
    padding: 14px;
    background: rgba(139, 107, 248, 0.06);
    border: 1px solid color-mix(in srgb, var(--accent) 22%, transparent);
    border-radius: 12px;
  }
  .key-section h3 { font-size: 12px; font-weight: 700; color: var(--accent); letter-spacing: 0.02em; }
  .key-section p { font-size: 11.5px; color: var(--text-secondary); }
  .key-row { display: flex; gap: 8px; }
  .key-row input {
    flex: 1;
    padding: 9px 12px;
    border-radius: 9px;
    font-family: var(--font-mono);
    font-size: 12px;
    background: rgba(0, 0, 0, 0.45);
    border: 1px solid rgba(255, 255, 255, 0.12);
    color: #fff;
    outline: none;
  }
  .key-row input:focus { border-color: var(--accent); }
  .key-row input.error { border-color: var(--danger); }
  .validate {
    padding: 9px 16px;
    border-radius: 9px;
    font-size: 12px; font-weight: 700;
    background: linear-gradient(135deg, var(--accent), var(--accent-2));
    color: #fff;
    box-shadow: 0 6px 14px rgba(139, 107, 248, 0.32);
  }
  .validate:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 10px 20px rgba(139, 107, 248, 0.42); }
  .validate:disabled { opacity: 0.5; cursor: not-allowed; }
  .err { font-size: 11.5px; color: var(--danger); font-weight: 600; }

  footer {
    display: flex; justify-content: flex-end; gap: 8px;
    padding: 14px 18px 16px;
    border-top: 1px solid rgba(255, 255, 255, 0.06);
  }
  .ghost {
    padding: 8px 14px;
    border-radius: 9px;
    color: var(--text-secondary);
    font-size: 12px;
  }
  .ghost:hover { color: #fff; background: rgba(255, 255, 255, 0.05); }
  .primary {
    padding: 8px 16px;
    border-radius: 9px;
    font-size: 12px; font-weight: 700;
    background: rgba(255, 255, 255, 0.10);
    color: #fff;
    border: 1px solid var(--border);
  }
  .primary:hover { background: rgba(255, 255, 255, 0.14); }
</style>
