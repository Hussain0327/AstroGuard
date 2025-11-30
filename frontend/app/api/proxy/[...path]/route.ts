import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = 'http://localhost:8000/api/v1';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params;
  const targetPath = path.join('/');
  const url = new URL(request.url);
  const queryString = url.search;

  try {
    const response = await fetch(`${BACKEND_URL}/${targetPath}${queryString}`, {
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const text = await response.text();
      try {
        const json = JSON.parse(text);
        return NextResponse.json(json, { status: response.status });
      } catch {
        return NextResponse.json({ detail: text }, { status: response.status });
      }
    }

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Proxy error:', error);
    return NextResponse.json({ detail: 'Backend unavailable' }, { status: 503 });
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params;
  const targetPath = path.join('/');
  const url = new URL(request.url);
  const queryString = url.search;

  try {
    const contentType = request.headers.get('content-type') || '';

    let response: Response;

    if (contentType.includes('multipart/form-data')) {
      // For multipart/form-data, we need to rebuild the FormData
      const incomingFormData = await request.formData();
      const outgoingFormData = new FormData();

      for (const [key, value] of incomingFormData.entries()) {
        if (value instanceof File) {
          // Read file content and re-create with proper encoding
          const arrayBuffer = await value.arrayBuffer();

          // Determine MIME type
          const mimeType = value.type;
          const isCSV = value.name.toLowerCase().endsWith('.csv');
          const isExcel = value.name.toLowerCase().endsWith('.xlsx');

          if (isCSV) {
            // For CSV files, decode as text and re-encode to ensure proper UTF-8
            const decoder = new TextDecoder('utf-8');
            const text = decoder.decode(arrayBuffer);
            const blob = new Blob([text], { type: 'text/csv; charset=utf-8' });
            outgoingFormData.append(key, blob, value.name);
          } else if (isExcel) {
            // For Excel files, keep as binary
            const blob = new Blob([arrayBuffer], {
              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            });
            outgoingFormData.append(key, blob, value.name);
          } else {
            // Other files - keep original
            const blob = new Blob([arrayBuffer], { type: mimeType || 'application/octet-stream' });
            outgoingFormData.append(key, blob, value.name);
          }
        } else {
          outgoingFormData.append(key, value);
        }
      }

      response = await fetch(`${BACKEND_URL}/${targetPath}${queryString}`, {
        method: 'POST',
        body: outgoingFormData,
      });
    } else if (contentType.includes('application/json')) {
      // Read raw text first to handle potential encoding issues
      const rawBody = await request.text();
      let jsonBody: unknown;
      try {
        jsonBody = JSON.parse(rawBody);
      } catch {
        // If JSON parsing fails, forward as text
        response = await fetch(`${BACKEND_URL}/${targetPath}${queryString}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: rawBody,
        });

        if (!response.ok) {
          const text = await response.text();
          try {
            const json = JSON.parse(text);
            return NextResponse.json(json, { status: response.status });
          } catch {
            return NextResponse.json({ detail: text }, { status: response.status });
          }
        }
        const data = await response.json();
        return NextResponse.json(data, { status: response.status });
      }

      response = await fetch(`${BACKEND_URL}/${targetPath}${queryString}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(jsonBody),
      });
    } else {
      const textBody = await request.text();
      response = await fetch(`${BACKEND_URL}/${targetPath}${queryString}`, {
        method: 'POST',
        body: textBody,
      });
    }

    if (!response.ok) {
      const text = await response.text();
      try {
        const json = JSON.parse(text);
        return NextResponse.json(json, { status: response.status });
      } catch {
        return NextResponse.json({ detail: text }, { status: response.status });
      }
    }

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Proxy error:', error);
    return NextResponse.json({ detail: 'Backend unavailable' }, { status: 503 });
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params;
  const targetPath = path.join('/');

  try {
    const response = await fetch(`${BACKEND_URL}/${targetPath}`, {
      method: 'DELETE',
    });

    if (!response.ok) {
      const text = await response.text();
      try {
        const json = JSON.parse(text);
        return NextResponse.json(json, { status: response.status });
      } catch {
        return NextResponse.json({ detail: text }, { status: response.status });
      }
    }

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Proxy error:', error);
    return NextResponse.json({ detail: 'Backend unavailable' }, { status: 503 });
  }
}
