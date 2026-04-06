const http = require('http');
http.get('http://localhost:80/', (r) => {
  process.exit(r.statusCode < 500 ? 0 : 1);
}).on('error', () => process.exit(1));
