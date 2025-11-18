# 📤 Workflow: Carga de Documentos a Base de Conocimientos

## 🎯 Objetivo
Este workflow permite cargar documentos a Supabase con embeddings de OpenAI para búsqueda semántica (RAG).

---

## 📋 Flujo del Workflow

```
Trigger (Manual/Schedule/Webhook)
  ↓
Leer Fuente de Datos (CSV/Google Sheets/Airtable)
  ↓
Split en Items (un item por documento)
  ↓
Code: Limpiar y formatear texto
  ↓
OpenAI: Generar Embedding
  ↓
Supabase: Insertar documento
  ↓
Set: Contador de éxitos
  ↓
Fin: Notificar resultado
```

---

## 🔧 Configuración Paso a Paso

### OPCIÓN A: Carga desde CSV

#### 1. Nodo "Trigger Manual"
- **Tipo**: Manual Trigger
- **Nombre**: "Iniciar Carga"
- **Descripción**: Click para comenzar carga de documentos

#### 2. Nodo "Leer CSV"
- **Tipo**: Read/Write Files from Disk
- **Operación**: Read From File
- **File Path**: `/home/user/documentos_ximaro.csv`
- **Formato**: CSV con headers
- **Settings**:
  - Include Headers: ✅
  - Delimiter: `,`

**Formato esperado del CSV**:
```csv
titulo,content,categoria,marca,precio,stock
Shampoo Dove 400ml,"Shampoo Dove Original 400ml. Ideal para todo tipo de cabello...",higiene,Dove,2500,500
Detergente Ariel 1L,"Detergente Ariel líquido concentrado...",limpieza,Ariel,3200,300
```

#### 3. Nodo "Split Items"
- **Tipo**: Split Out
- **Campo**: Automático (cada fila = 1 item)

#### 4. Nodo "Formatear Documento"
- **Tipo**: Code (JavaScript)
- **Código**:

```javascript
// Crear contenido completo del documento
const titulo = $input.item.json.titulo || '';
const content = $input.item.json.content || '';
const categoria = $input.item.json.categoria || '';
const marca = $input.item.json.marca || '';
const precio = $input.item.json.precio || 0;
const stock = $input.item.json.stock || 0;

// Formatear texto completo para embedding
const textoCompleto = `
${titulo}

${content}

Categoría: ${categoria}
Marca: ${marca}
Precio mayorista: $${precio}
Stock disponible: ${stock} unidades
`.trim();

// Metadata en JSON
const metadata = {
  titulo: titulo,
  categoria: categoria,
  marca: marca,
  precio: parseInt(precio),
  stock: parseInt(stock),
  fecha_carga: new Date().toISOString()
};

return {
  json: {
    texto_para_embedding: textoCompleto,
    metadata: metadata,
    original: $input.item.json
  }
};
```

#### 5. Nodo "Generar Embedding"
- **Tipo**: OpenAI
- **Credencial**: Tu OpenAI API Key
- **Resource**: Embeddings
- **Model**: text-embedding-ada-002
- **Input Text**: `={{ $json.texto_para_embedding }}`

**Output esperado**:
```json
{
  "data": [
    {
      "embedding": [0.123, 0.456, ..., 0.789], // 1536 números
      "index": 0
    }
  ]
}
```

#### 6. Nodo "Preparar para Supabase"
- **Tipo**: Code (JavaScript)
- **Código**:

```javascript
// Extraer embedding del response de OpenAI
const embedding = $input.item.json.data[0].embedding;
const metadata = $('Formatear Documento').item.json.metadata;
const content = $('Formatear Documento').item.json.texto_para_embedding;

return {
  json: {
    content: content,
    metadata: metadata,
    embedding: embedding
  }
};
```

#### 7. Nodo "Insertar en Supabase"
- **Tipo**: HTTP Request
- **Method**: POST
- **URL**: `https://YOUR_PROJECT.supabase.co/rest/v1/documentos_ximaro`
- **Authentication**: Generic Credential Type
  - Header Auth
  - Name: `apikey`
  - Value: `{{ $credentials.supabaseServiceRole }}`
- **Headers**:
  ```
  Authorization: Bearer {{ $credentials.supabaseServiceRole }}
  apikey: {{ $credentials.supabaseServiceRole }}
  Content-Type: application/json
  Prefer: return=minimal
  ```
- **Body**:
  ```json
  {
    "content": "={{ $json.content }}",
    "metadata": "={{ $json.metadata }}",
    "embedding": "={{ $json.embedding }}"
  }
  ```

#### 8. Nodo "Contador"
- **Tipo**: Code (JavaScript)
- **Run Once for All Items**: ✅
- **Código**:

```javascript
const items = $input.all();
const exitosos = items.filter(item => item.json.status !== 'error').length;
const errores = items.length - exitosos;

return {
  json: {
    total_procesados: items.length,
    exitosos: exitosos,
    errores: errores,
    mensaje: `✅ Carga completada: ${exitosos} documentos cargados, ${errores} errores`
  }
};
```

#### 9. Nodo "Notificar" (Opcional)
- **Tipo**: Send Email / Slack / Discord
- **Mensaje**: `{{ $json.mensaje }}`

---

### OPCIÓN B: Carga desde Google Sheets

#### 1. Nodo "Google Sheets"
- **Tipo**: Google Sheets
- **Operación**: Read
- **Spreadsheet ID**: ID de tu hoja
- **Sheet Name**: "Productos"
- **Range**: A1:F1000 (ajustar según necesidad)

Luego continuar desde el paso 3 de la Opción A (Split Items).

---

### OPCIÓN C: Carga desde Airtable

#### 1. Nodo "Airtable"
- **Tipo**: Airtable
- **Operación**: List
- **Base ID**: Tu base de Airtable
- **Table**: "Productos"
- **Return All**: ✅

Luego continuar desde el paso 3 de la Opción A (Split Items).

---

## 🔄 Workflow Incremental (solo nuevos documentos)

Para evitar duplicados, agregar antes del paso "Generar Embedding":

#### Nodo "Verificar si existe"
- **Tipo**: HTTP Request
- **Method**: GET
- **URL**: `https://YOUR_PROJECT.supabase.co/rest/v1/documentos_ximaro?metadata->>titulo=eq.{{ $json.titulo }}`
- **Headers**: (mismos que antes)

#### Nodo "If: No existe"
- **Tipo**: IF
- **Condición**: `{{ $json.length === 0 }}`
- **True** → Continuar con Generar Embedding
- **False** → Skip (o actualizar)

---

## 🧪 Testing

### Test con 1 documento

1. Crear CSV con 1 sola línea:
```csv
titulo,content,categoria,marca,precio,stock
Test Product,"Producto de prueba para testing",test,TestBrand,100,10
```

2. Ejecutar workflow
3. Verificar en Supabase:
```sql
select * from documentos_ximaro where metadata->>'categoria' = 'test';
```

4. Si funciona → cargar todos los documentos

---

## 📊 Estimación de costos

### OpenAI Embeddings (text-embedding-ada-002)
- **Costo**: $0.0001 por 1,000 tokens
- **Promedio**: ~500 tokens por documento = $0.00005
- **1,000 documentos**: ~$0.05 USD
- **10,000 documentos**: ~$0.50 USD

**MUY ECONÓMICO** 💰

### Supabase
- **Plan Free**: 500MB de base de datos
- **Estimación**: ~5KB por documento (texto + embedding)
- **Capacidad**: ~100,000 documentos en plan free

---

## 🚨 Troubleshooting

### Error: "Invalid API Key"
→ Verifica OpenAI API Key en credenciales

### Error: "Permission denied"
→ Usa `service_role` key de Supabase, no `anon` key

### Error: "Vector dimension mismatch"
→ Verifica que uses `text-embedding-ada-002` (1536 dims)

### Documentos duplicados
→ Implementa verificación de existencia (ver workflow incremental)

### Muy lento
→ Reduce batch size o usa workflow con Sleep entre requests

---

## 🎯 Próximo paso

Una vez cargados los documentos, usar el workflow principal con RAG para consultas inteligentes.
