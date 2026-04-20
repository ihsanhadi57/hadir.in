// Test Jimp v1 composite workflow
const { Jimp } = require('jimp');
const QRCode = require('qrcode');
const path = require('path');
const fs = require('fs');

async function test() {
  // 1. Generate QR buffer
  const qrBuffer = await QRCode.toBuffer('test-ticket-123', {
    errorCorrectionLevel: 'H',
    margin: 2,
    width: 200,
  });
  console.log('QR buffer size:', qrBuffer.length);

  // 2. Read template (use dummy)
  const template = new Jimp({ width: 800, height: 400, color: 0xFFCCAAFF });
  console.log('Template created:', template.width, 'x', template.height);

  // 3. Read QR as Jimp image
  const qrImg = await Jimp.read(qrBuffer);
  console.log('QR image:', qrImg.width, 'x', qrImg.height);

  // 4. Composite
  template.composite(qrImg, 500, 100);
  console.log('Composite done');

  // 5. Get buffer
  const buf = await template.getBuffer('image/png');
  console.log('Final buffer size:', buf.length);
  
  fs.writeFileSync(path.join(__dirname, 'test_output.png'), buf);
  console.log('Written test_output.png successfully!');
}

test().catch(e => console.error('FAILED:', e));
