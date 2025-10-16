// Vercel Serverless Function - Enhancement Status Check
const API_KEY = 'bae0c714-f708-4d00-99b3-b740d0af3fda';

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const { jobId } = req.query;

  try {
    const response = await fetch(`https://api.maxstudio.ai/image-enhancer/${jobId}`, {
      headers: { 'x-api-key': API_KEY }
    });

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
