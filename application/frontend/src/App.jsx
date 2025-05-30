import { useState } from 'react';

function App() {
  const [originalUrl, setOriginalUrl] = useState('');
  const [shortId, setShortId] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setShortId('');
    setError('');

    try {
      const response = await fetch('/api/shorten', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: originalUrl }),
      });

      if (!response.ok) {
        throw new Error("Failed to shorten URL");
      }

      const data = await response.json();
      setShortId(data.short_id);
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div style={{ padding: '2rem', maxWidth: '600px', margin: '0 auto', fontFamily: 'sans-serif' }}>
      <h1>URL Shortener</h1>
      <form onSubmit={handleSubmit}>
        <input
          type="url"
          placeholder="Enter long URL"
          value={originalUrl}
          onChange={(e) => setOriginalUrl(e.target.value)}
          style={{ width: '100%', padding: '0.5rem', fontSize: '1rem' }}
          required
        />
        <button type="submit" style={{ marginTop: '1rem', padding: '0.5rem 1rem' }}>
          Shorten
        </button>
      </form>

      {shortId && (
        <p style={{ marginTop: '1rem' }}>
          Short URL:{' '}
          <a
            href={`/api/${shortId}`}
            target="_blank"
            rel="noopener noreferrer"
          >
            {window.location.origin}/api/{shortId}
          </a>
        </p>
      )}

      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  );
}

export default App;
