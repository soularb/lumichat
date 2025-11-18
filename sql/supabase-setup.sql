-- ============================================
-- SETUP COMPLETO DE SUPABASE PARA RAG
-- Proyecto: LumiChat - XIMARO
-- Base de datos vectorial con pgvector
-- ============================================

-- PASO 1: Habilitar extensión pgvector
-- Esta extensión permite almacenar y buscar vectores
create extension if not exists vector;

-- ============================================
-- PASO 2: Crear tabla de documentos
-- ============================================

create table if not exists documentos_ximaro (
  id bigserial primary key,
  content text not null,                    -- Texto del documento
  metadata jsonb,                           -- Info adicional (categoría, precio, etc.)
  embedding vector(1536),                   -- Vector de OpenAI (1536 dimensiones)
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Comentarios para documentación
comment on table documentos_ximaro is 'Almacena documentos embedidos para búsqueda semántica RAG';
comment on column documentos_ximaro.content is 'Texto completo del documento';
comment on column documentos_ximaro.metadata is 'Metadatos en JSON: {categoria, marca, precio, etc}';
comment on column documentos_ximaro.embedding is 'Vector de 1536 dimensiones (OpenAI text-embedding-ada-002)';

-- ============================================
-- PASO 3: Crear índices para performance
-- ============================================

-- Índice vectorial para búsquedas semánticas rápidas
-- ivfflat es un algoritmo de búsqueda aproximada optimizado
create index if not exists documentos_ximaro_embedding_idx
on documentos_ximaro
using ivfflat (embedding vector_cosine_ops)
with (lists = 100);

-- Índice GIN para búsquedas en metadata (JSON)
create index if not exists documentos_ximaro_metadata_idx
on documentos_ximaro using gin (metadata);

-- Índice para búsquedas por fecha
create index if not exists documentos_ximaro_created_at_idx
on documentos_ximaro (created_at desc);

-- ============================================
-- PASO 4: Función de búsqueda semántica
-- ============================================

create or replace function match_documentos_ximaro (
  query_embedding vector(1536),
  match_threshold float default 0.78,
  match_count int default 5,
  filter_metadata jsonb default '{}'
)
returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql stable
as $$
begin
  return query
  select
    documentos_ximaro.id,
    documentos_ximaro.content,
    documentos_ximaro.metadata,
    1 - (documentos_ximaro.embedding <=> query_embedding) as similarity
  from documentos_ximaro
  where
    -- Filtro de similitud
    1 - (documentos_ximaro.embedding <=> query_embedding) > match_threshold
    -- Filtro opcional por metadata
    and (
      filter_metadata = '{}'::jsonb
      or documentos_ximaro.metadata @> filter_metadata
    )
  order by documentos_ximaro.embedding <=> query_embedding
  limit match_count;
end;
$$;

comment on function match_documentos_ximaro is 'Busca documentos similares usando búsqueda vectorial';

-- ============================================
-- PASO 5: Función de búsqueda por categoría
-- ============================================

create or replace function buscar_por_categoria (
  categoria_nombre text,
  limite int default 10
)
returns table (
  id bigint,
  content text,
  metadata jsonb
)
language sql stable
as $$
  select
    id,
    content,
    metadata
  from documentos_ximaro
  where metadata->>'categoria' = categoria_nombre
  order by created_at desc
  limit limite;
$$;

comment on function buscar_por_categoria is 'Busca documentos por categoría en metadata';

-- ============================================
-- PASO 6: Trigger para updated_at automático
-- ============================================

create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_documentos_ximaro_updated_at
before update on documentos_ximaro
for each row
execute function update_updated_at_column();

-- ============================================
-- PASO 7: Row Level Security (RLS)
-- ============================================

-- Habilitar RLS
alter table documentos_ximaro enable row level security;

-- Política: Lectura pública (con anon key)
drop policy if exists "Permitir lectura pública" on documentos_ximaro;
create policy "Permitir lectura pública"
on documentos_ximaro for select
to anon, authenticated
using (true);

-- Política: Escritura solo con service_role
drop policy if exists "Permitir inserción autenticada" on documentos_ximaro;
create policy "Permitir inserción autenticada"
on documentos_ximaro for insert
to service_role
with check (true);

-- Política: Actualización solo con service_role
drop policy if exists "Permitir actualización autenticada" on documentos_ximaro;
create policy "Permitir actualización autenticada"
on documentos_ximaro for update
to service_role
using (true);

-- Política: Borrado solo con service_role
drop policy if exists "Permitir borrado autenticado" on documentos_ximaro;
create policy "Permitir borrado autenticado"
on documentos_ximaro for delete
to service_role
using (true);

-- ============================================
-- PASO 8: Vistas útiles
-- ============================================

-- Vista: Estadísticas de documentos
create or replace view stats_documentos as
select
  count(*) as total_documentos,
  count(distinct metadata->>'categoria') as total_categorias,
  count(distinct metadata->>'marca') as total_marcas,
  min(created_at) as primer_documento,
  max(created_at) as ultimo_documento
from documentos_ximaro;

comment on view stats_documentos is 'Estadísticas generales de la base de conocimientos';

-- Vista: Documentos por categoría
create or replace view documentos_por_categoria as
select
  metadata->>'categoria' as categoria,
  count(*) as cantidad,
  max(created_at) as ultimo_actualizado
from documentos_ximaro
where metadata->>'categoria' is not null
group by metadata->>'categoria'
order by cantidad desc;

comment on view documentos_por_categoria is 'Cuenta documentos agrupados por categoría';

-- ============================================
-- PASO 9: Datos de ejemplo (OPCIONAL)
-- ============================================

-- Descomentar para insertar datos de prueba
-- NOTA: Necesitas embeddings reales de OpenAI para esto
-- Este es solo un ejemplo de estructura

/*
insert into documentos_ximaro (content, metadata, embedding) values
(
  'Shampoo Dove Original 400ml. Ideal para todo tipo de cabello. Proporciona hidratación profunda y suavidad. Precio mayorista: $2500 por unidad. Stock disponible: 500 unidades. Presentación en caja de 12 unidades.',
  '{"categoria": "higiene", "marca": "Dove", "producto": "Shampoo", "presentacion": "400ml", "precio": 2500, "stock": 500, "unidades_caja": 12}'::jsonb,
  '[0.1, 0.2, ...]'::vector -- Aquí va el embedding real de OpenAI
),
(
  'Detergente Ariel líquido concentrado 1L. Limpieza profunda para ropa blanca y de color. Rendimiento: 20 lavados. Precio mayorista: $3200 por unidad. Stock disponible: 300 unidades.',
  '{"categoria": "limpieza", "marca": "Ariel", "producto": "Detergente", "presentacion": "1L", "precio": 3200, "stock": 300, "rendimiento": "20 lavados"}'::jsonb,
  '[0.3, 0.4, ...]'::vector
);
*/

-- ============================================
-- PASO 10: Funciones de utilidad
-- ============================================

-- Función: Contar documentos totales
create or replace function count_documentos()
returns bigint
language sql stable
as $$
  select count(*) from documentos_ximaro;
$$;

-- Función: Eliminar documentos antiguos (housekeeping)
create or replace function limpiar_documentos_antiguos(dias int default 365)
returns int
language plpgsql
as $$
declare
  deleted_count int;
begin
  delete from documentos_ximaro
  where created_at < now() - interval '1 day' * dias;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

comment on function limpiar_documentos_antiguos is 'Elimina documentos más antiguos que N días';

-- ============================================
-- VERIFICACIÓN FINAL
-- ============================================

-- Verifica que todo se creó correctamente
do $$
begin
  raise notice '✅ Extensión vector: %', (select extname from pg_extension where extname = 'vector');
  raise notice '✅ Tabla documentos_ximaro: %', (select to_regclass('public.documentos_ximaro'));
  raise notice '✅ Función match_documentos_ximaro: %', (select to_regproc('public.match_documentos_ximaro'));
  raise notice '✅ Total de documentos: %', (select count_documentos());
  raise notice '';
  raise notice '🎉 Setup completado exitosamente!';
  raise notice '';
  raise notice 'Siguientes pasos:';
  raise notice '1. Obtener credenciales de Supabase (Project URL + API Keys)';
  raise notice '2. Obtener OpenAI API Key';
  raise notice '3. Cargar documentos con embeddings';
  raise notice '4. Integrar con n8n workflow';
end $$;

-- ============================================
-- EJEMPLOS DE CONSULTAS
-- ============================================

/*
-- Ver todos los documentos
select id, content, metadata from documentos_ximaro;

-- Ver estadísticas
select * from stats_documentos;

-- Ver documentos por categoría
select * from documentos_por_categoria;

-- Buscar por categoría
select * from buscar_por_categoria('higiene', 10);

-- Buscar documentos similares (necesitas embedding real)
select * from match_documentos_ximaro(
  '[0.1, 0.2, ...]'::vector(1536),  -- embedding de consulta
  0.78,                               -- umbral de similitud
  5                                   -- cantidad de resultados
);

-- Buscar con filtro de metadata
select * from match_documentos_ximaro(
  '[0.1, 0.2, ...]'::vector(1536),
  0.78,
  5,
  '{"categoria": "higiene"}'::jsonb   -- solo documentos de higiene
);

-- Contar documentos
select count_documentos();

-- Limpiar documentos antiguos (más de 1 año)
select limpiar_documentos_antiguos(365);
*/
