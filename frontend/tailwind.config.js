/** @type {import('tailwindcss').Config} */
export default {
  // 'class'-Strategie: dark-Klasse auf <html> steuert Dark Mode
  darkMode: 'class',
  content: [
    './index.html',
    './src/**/*.{vue,ts}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
