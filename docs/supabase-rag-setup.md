# 🚀 Guía Completa: Base de Datos Vectorial RAG con Supabase

## 📋 Tabla de Contenidos
1. [¿Qué es RAG y por qué usarlo?](#qué-es-rag)
2. [Configuración inicial de Supabase](#configuración-supabase)
3. [Crear base de datos vectorial](#crear-base-datos-vectorial)
4. [Integración con n8n](#integración-n8n)
5. [Carga de documentos](#carga-documentos)
6. [Testing y optimización](#testing)

---

## 🤔 ¿Qué es RAG y por qué usarlo?

### RAG (Retrieval Augmented Generation)
Es una técnica que combina:
- **Búsqueda semántica** en tu base de conocimientos
- **Generación de respuestas** con IA usando información relevante

### ¿Cuándo usar RAG?
✅ **SÍ necesitas RAG si tienes:**
- Catálogo extenso de productos (+100 items)
- Políticas/documentación compleja que cambia frecuentemente
- Especificaciones técnicas detalladas
- FAQ extenso
- Múltiples categorías de productos

❌ **NO necesitas RAG si:**
- Tienes <50 productos simples
- El prompt actual responde bien todas las consultas
- No hay cambios frecuentes en información

### Beneficios para XIMARO
- 🎯 Respuestas precisas sobre productos específicos
- 📊 Consultas de catálogo sin límites de tokens
- 🔄 Actualización fácil sin modificar prompts
- 💰 Ahorro en costos de tokens (solo busca lo relevante)

---

## 🛠️ Configuración inicial de Supabase

### Paso 1: Crear cuenta en Supabase

1. Ve a [https://supabase.com](https://supabase.com)
2. Click en "Start your project"
3. Crea cuenta con GitHub, Google o email
4. **Es GRATIS** para proyectos pequeños (hasta 500MB de DB + 50MB de archivos)

### Paso 2: Crear nuevo proyecto

1. En el dashboard, click "New Project"
2. Completa los datos:
   - **Name**: `ximaro-rag` (o el nombre que prefieras)
   - **Database Password**: Genera una segura (GUÁRDALA!)
   - **Region**: `South America (São Paulo)` (más cercano a Argentina)
   - **Pricing Plan**: Free (suficiente para comenzar)
3. Click "Create new project"
4. **Espera 2-3 minutos** mientras se crea

### Paso 3: Obtener credenciales

Una vez creado el proyecto:

1. Ve a **Settings** (⚙️ en menú izquierdo)
2. Click en **API**
3. **GUARDA estos datos** (los necesitarás después):

```
Project URL: https://xxxxxxxxxxxxx.supabase.co
API Key (anon/public): eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
API Key (service_role): eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... (¡SECRETO!)
```

⚠️ **IMPORTANTE**:
- `anon key` → Para consultas públicas (búsquedas)
- `service_role key` → Para operaciones administrativas (insertar documentos)

---

## 🗄️ Crear base de datos vectorial

### Paso 1: Habilitar extensión pgvector

1. En Supabase, ve a **SQL Editor** (📝 en menú izquierdo)
2. Click en "+ New query"
3. Pega este código:

```sql
-- Habilitar extensión para vectores
create extension if not exists vector;
```

4. Click en "Run" ▶️
5. Deberías ver: ✅ "Success. No rows returned"

### Paso 2: Crear tabla de documentos

Copia y ejecuta este SQL:

```sql
-- Crear tabla para documentos embedidos
create table documentos_ximaro (
  id bigserial primary key,
  content text not null,
  metadata jsonb,
  embedding vector(1536), -- OpenAI embeddings son de 1536 dimensiones
  created_at timestamp with time zone default now()
);

-- Crear índice para búsquedas vectoriales rápidas
create index on documentos_ximaro
using ivfflat (embedding vector_cosine_ops)
with (lists = 100);

-- Índice para búsquedas por metadata
create index on documentos_ximaro using gin (metadata);
```

**Explicación**:
- `content`: El texto del documento (producto, política, etc.)
- `metadata`: Info adicional en JSON (categoría, precio, etc.)
- `embedding`: Vector de 1536 dimensiones (OpenAI text-embedding-ada-002)
- `ivfflat`: Índice optimizado para búsquedas vectoriales rápidas

### Paso 3: Crear función de búsqueda

Esta función encuentra los documentos más similares a una consulta:

```sql
create or replace function match_documentos_ximaro (
  query_embedding vector(1536),
  match_threshold float default 0.78,
  match_count int default 5
)
returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language sql stable
as $$
  select
    documentos_ximaro.id,
    documentos_ximaro.content,
    documentos_ximaro.metadata,
    1 - (documentos_ximaro.embedding <=> query_embedding) as similarity
  from documentos_ximaro
  where 1 - (documentos_ximaro.embedding <=> query_embedding) > match_threshold
  order by documentos_ximaro.embedding <=> query_embedding
  limit match_count;
$$;
```

**Parámetros**:
- `query_embedding`: Vector de la consulta del usuario
- `match_threshold`: Umbral de similitud (0.78 = 78% similar mínimo)
- `match_count`: Máximo de documentos a retornar (5 por defecto)

### Paso 4: Configurar políticas de seguridad (RLS)

```sql
-- Habilitar Row Level Security
alter table documentos_ximaro enable row level security;

-- Política: Permitir lectura pública (con anon key)
create policy "Permitir lectura pública"
on documentos_ximaro for select
to anon
using (true);

-- Política: Permitir escritura solo con service_role key
create policy "Permitir inserción autenticada"
on documentos_ximaro for insert
to service_role
with check (true);
```

---

## 🔌 Integración con n8n

### Opción 1: Usando nodo Supabase Vector Store (Recomendado)

n8n tiene soporte nativo para Supabase + RAG. Configuración:

#### 1. Crear credencial de Supabase en n8n

1. En n8n, ve a **Settings** > **Credentials**
2. Click "+ Add Credential"
3. Busca "Supabase"
4. Completa:
   - **Host**: `https://xxxxxxxxxxxxx.supabase.co` (tu Project URL)
   - **Service Role Secret**: `eyJhbGci...` (tu service_role key)
5. Guarda

#### 2. Crear credencial de OpenAI

1. "+ Add Credential"
2. Busca "OpenAI"
3. Completa:
   - **API Key**: Tu OpenAI API key
4. Guarda

### Opción 2: Usando nodo HTTP Request (Manual)

Si prefieres control total:

```javascript
// Nodo Code: Generar embedding de consulta
const OpenAI = require('openai');
const openai = new OpenAI({ apiKey: '{{$credentials.openAiApi.apiKey}}' });

const query = $input.item.json.mensaje_usuario;

const embedding_response = await openai.embeddings.create({
  model: "text-embedding-ada-002",
  input: query,
});

return {
  json: {
    query: query,
    embedding: embedding_response.data[0].embedding
  }
};
```

```javascript
// Nodo HTTP Request: Buscar en Supabase
// Method: POST
// URL: https://xxxxxxxxxxxxx.supabase.co/rest/v1/rpc/match_documentos_ximaro
// Headers:
//   apikey: {{service_role_key}}
//   Authorization: Bearer {{service_role_key}}
//   Content-Type: application/json
// Body:
{
  "query_embedding": "{{$json.embedding}}",
  "match_threshold": 0.78,
  "match_count": 3
}
```

---

## 📦 Carga de documentos

### Método 1: Workflow de carga en n8n (Recomendado)

Voy a crear un workflow separado: `ximaro-cargar-conocimiento.json`

**Flujo**:
```
Trigger Manual/Webhook
  → Leer archivo/Google Sheets
  → Split documentos en chunks
  → Loop: Para cada chunk
    → Generar embedding (OpenAI)
    → Insertar en Supabase
```

### Método 2: Script Python (Para carga masiva)

```python
import openai
from supabase import create_client
import json

# Configuración
supabase_url = "https://xxxxx.supabase.co"
supabase_key = "service_role_key_aqui"
openai.api_key = "tu_openai_key"

supabase = create_client(supabase_url, supabase_key)

# Documentos a cargar
documentos = [
    {
        "content": "Producto: Shampoo Dove 400ml. Precio mayorista: $2500. Stock: 500 unidades. Categoría: Higiene Personal.",
        "metadata": {"categoria": "higiene", "marca": "Dove", "precio": 2500}
    },
    # ... más documentos
]

# Generar embeddings y cargar
for doc in documentos:
    # Generar embedding
    response = openai.embeddings.create(
        model="text-embedding-ada-002",
        input=doc["content"]
    )
    embedding = response.data[0].embedding

    # Insertar en Supabase
    supabase.table("documentos_ximaro").insert({
        "content": doc["content"],
        "metadata": doc["metadata"],
        "embedding": embedding
    }).execute()

    print(f"✅ Cargado: {doc['metadata'].get('marca', 'Doc')}")

print("🎉 Carga completa!")
```

### Método 3: Desde CSV/Excel

Formato del archivo:

```csv
content,categoria,marca,precio
"Shampoo Dove 400ml. Ideal para cabello seco. Hidratación profunda.",higiene,Dove,2500
"Detergente Ariel 1kg. Limpieza profunda. Para ropa blanca y de color.",limpieza,Ariel,3200
```

---

## 🔍 Testing y optimización

### 1. Probar búsqueda manualmente

En SQL Editor de Supabase:

```sql
-- Ver todos los documentos
select id, content, metadata from documentos_ximaro limit 10;

-- Probar función de búsqueda con un embedding de prueba
-- (necesitas un embedding real de OpenAI para esto)
```

### 2. Ajustar parámetros

Si obtienes **demasiados resultados irrelevantes**:
- Sube `match_threshold` de 0.78 a 0.82 o 0.85

Si obtienes **muy pocos resultados**:
- Baja `match_threshold` a 0.70 o 0.75

Si necesitas **más contexto**:
- Sube `match_count` de 5 a 8 o 10

### 3. Monitorear costos

**OpenAI Embeddings** (text-embedding-ada-002):
- Costo: $0.0001 por 1,000 tokens
- ~1 página = ~500 tokens = $0.00005
- 1,000 documentos = ~$0.05

**Supabase**:
- Plan Free: 500MB DB + 2GB ancho de banda/mes
- Suficiente para ~50,000 documentos pequeños

---

## 📊 Ejemplo completo de uso

### Consulta del usuario:
```
"Hola, necesito shampoo Dove para reventa, ¿qué precio tiene?"
```

### Flujo RAG:
1. **Generar embedding** de "necesito shampoo Dove para reventa precio"
2. **Buscar en Supabase** → Retorna top 3 documentos similares:
   ```json
   [
     {
       "content": "Shampoo Dove 400ml. Precio mayorista: $2500...",
       "metadata": {"categoria": "higiene", "precio": 2500},
       "similarity": 0.89
     },
     ...
   ]
   ```
3. **Crear prompt aumentado**:
   ```
   Contexto de base de conocimientos:
   - Shampoo Dove 400ml. Precio mayorista: $2500...

   Usuario pregunta: "necesito shampoo Dove para reventa, ¿qué precio tiene?"

   Responde usando SOLO la información del contexto.
   ```
4. **Generar respuesta** con Gemini/GPT
5. **Enviar al usuario**:
   ```
   ¡Hola! 😊 Tenemos Shampoo Dove 400ml en stock.
   Precio mayorista: $2500 por unidad.
   Tenemos 500 unidades disponibles.
   ¿Cuántas unidades necesitas?
   ```

---

## 🎯 Siguientes pasos

1. ✅ Configurar Supabase (15 min)
2. ✅ Ejecutar scripts SQL (5 min)
3. ✅ Obtener OpenAI API key
4. 📝 Preparar documentos de XIMARO (1-2 horas)
5. 🔄 Crear workflow de carga
6. 🧪 Testing con consultas reales
7. 🚀 Integrar en workflow principal

---

## 🆘 Troubleshooting

### Error: "function vector does not exist"
→ No se habilitó la extensión pgvector. Ejecuta:
```sql
create extension if not exists vector;
```

### Error: "permission denied for table documentos_ximaro"
→ Estás usando `anon` key para insertar. Usa `service_role` key.

### Búsquedas muy lentas
→ Verifica que el índice ivfflat esté creado:
```sql
select indexname from pg_indexes where tablename = 'documentos_ximaro';
```

### Resultados poco relevantes
→ Ajusta `match_threshold` o mejora el contenido de tus documentos.

---

## 📚 Recursos adicionales

- [Supabase Vector Docs](https://supabase.com/docs/guides/ai/vector-columns)
- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings)
- [n8n Supabase Integration](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.supabase/)

---

**¿Necesitas ayuda?** Revisa la sección de troubleshooting o consulta la documentación oficial.
