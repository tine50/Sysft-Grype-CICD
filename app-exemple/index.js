// Application exemple pour cas pratique Syft / SBOM
const express = require('express');
const _ = require('lodash');

const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.json({ message: 'App exemple pour SBOM', version: '1.0.0' });
});

app.listen(PORT, () => {
  console.log(`Serveur sur http://localhost:${PORT}`);
});
