export const environment = {
    production: true,
    // Para Docker: usa /api (nginx hace proxy al backend)
    // Para desarrollo local: usa http://localhost:4000/api
    apiUrl: '/api',
    version: '5.6.0',
};