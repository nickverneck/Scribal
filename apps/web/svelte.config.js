import { vitePreprocess } from '@sveltejs/kit/vite';

export default {
  preprocess: vitePreprocess(),
  kit: {
    alias: {
      $lib: 'src/lib'
    }
  }
};

