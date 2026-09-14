/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{html,ts}",
  ],
  theme: {
    extend: {
      colors: {
        primary: '#1957FF',
        'primary-dark': '#3F65E0',
        'primary-light': '#E6F0FF',
        danger: '#ff0000',
        'danger-light': '#ffebee',
        success: '#28a745',
        warning: '#ffc107',
        'bg-light': '#F9FCFF',
        'bg-card': '#FBFCFF',
      },
      screens: {
        'tablet': '768px',
        'desktop': '1024px',
        'wide': '1360px',
      },
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
      },
      borderRadius: {
        'xl': '1rem',
        '2xl': '1.5rem',
      },
      boxShadow: {
        'card': '0 2px 8px rgba(0, 0, 0, 0.1)',
        'card-hover': '0 4px 16px rgba(0, 0, 0, 0.15)',
      },
      animation: {
        'blink': 'blink 1.6s ease-in-out infinite',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        blink: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.5' },
        },
      },
    },
  },
  plugins: [],
}
