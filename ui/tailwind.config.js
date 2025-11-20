/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        fm: {
          purple: '#2e1a47', // Deep purple
          dark: '#191919',   // Almost black
          teal: '#1cc6d2',   // FM Teal accent
          light: '#e6e6e6',  // Light grey text
          surface: '#372354', // Slightly lighter purple for cards
          danger: '#e11d48', // Red for warnings
          success: '#22c55e', // Green for success
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      }
    },
  },
  plugins: [],
}

