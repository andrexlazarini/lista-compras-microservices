const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const AWS = require('aws-sdk');

const PORT = process.env.PORT || 3001;
const BUCKET = process.env.S3_BUCKET || 'shopping-images';
const REGION = process.env.AWS_REGION || 'us-east-1';
const ENDPOINT = process.env.AWS_ENDPOINT || 'http://localhost:4566'; // LocalStack

// AWS SDK v2 config (LocalStack)
AWS.config.update({
  region: REGION,
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
});

const s3 = new AWS.S3({
  endpoint: ENDPOINT,
  s3ForcePathStyle: true, // necessário no LocalStack
});

const app = express();
app.use(cors());
app.use(express.json({ limit: '15mb' }));

const upload = multer({ storage: multer.memoryStorage() });

app.get('/health', (req, res) => res.json({ ok: true }));

// Multipart upload: field name = "file"
app.post('/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Arquivo não enviado. Use campo multipart "file".' });
    }

    const ext = (req.file.originalname || '').split('.').pop() || 'jpg';
    const key = `tasks/${Date.now()}-${uuidv4()}.${ext}`;

    await s3.putObject({
      Bucket: BUCKET,
      Key: key,
      Body: req.file.buffer,
      ContentType: req.file.mimetype || 'application/octet-stream',
    }).promise();

    // URL de acesso via LocalStack (path-style)
    const url = `${ENDPOINT.replace('localhost', '10.0.2.2')}/${BUCKET}/${key}`;

    return res.status(201).json({ key, url });
  } catch (err) {
    console.error('UPLOAD ERROR:', err);
    return res.status(500).json({ error: 'Falha no upload', details: String(err) });
  }
});

app.listen(PORT, () => {
  console.log(`Media service running on http://localhost:${PORT}`);
  console.log(`Target S3 endpoint: ${ENDPOINT}, bucket: ${BUCKET}`);
});
