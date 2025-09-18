<script lang="ts">
  export let data;
</script>

<slot />

<style>
  :root { color-scheme: light dark; }
  body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Helvetica, Arial, Apple Color Emoji, Segoe UI Emoji; }
  .container { max-width: 1200px; margin: 0 auto; padding: 1rem; }
  header { display: flex; align-items: center; gap: .75rem; padding: .75rem 0; }
  header h1 { font-size: 1.1rem; margin: 0; }
  a { color: inherit; text-decoration: none; }
</style>

