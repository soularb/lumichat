# 📋 Proyecto LumiChat - Mejora Automatización n8n

**Fecha de inicio**: 2025-11-18
**Cliente**: XIMARO (Importadora mayorista)
**Objetivo**: Mejorar automatización existente integrando funcionalidades avanzadas de sistema de peluquería

---

## 📊 Estado del Proyecto

### Automatizaciones Analizadas

#### ✅ Automatización 1: Chatwoot AI XIMARO - Debug
- **Plataforma**: Chatwoot
- **Modelo IA**: Google Gemini
- **Estado**: Funcional
- **Archivo**: Entregado y analizado

#### ✅ Automatización 2: WhatsApp COMPLETO - Agenda Citas + Derivaciones
- **Plataforma**: WhatsApp (Evolution API)
- **Modelo IA**: OpenAI GPT-5-mini + GPT-4.1-mini
- **Estado**: Referencia para mejoras
- **Archivo**: Entregado y analizado completo

---

## 🏗️ Arquitectura Actual (XIMARO)

### Flujo Principal
```
Webhook (Chatwoot)
  ↓
If (filtrar outgoing)
  ↓
Extraer Conversation ID
  ↓
Obtener Labels Actuales
  ↓
Configuración (datos + prompt)
  ↓
AI Agent (Gemini + Memory 20 msgs)
  ↓
Extraer Clasificación (6 categorías + confianza)
  ↓
Enviar Respuesta
  ↓
Aplicar Etiqueta
  ↓
¿Escalar a Humano? (si categoría especial O confianza <60%)
  ↓
Asignar Agente Humano / Fin Normal
```

### Datos del Servidor
- **URL Chatwoot**: `alvaro-chatwoot.5epeub.easypanel.host`
- **API Token**: `fLi8hi4RtbiBZs4okugg9VDL`
- **Account ID**: `2`
- **Assignee ID**: `1`

### Categorías de Clasificación
1. `interes_inicial` - Primer contacto, consultas generales
2. `contacto_obtenido` - Email proporcionado
3. `seguimiento_humano` - Intención firme de compra
4. `venta_cerrada` - Compra confirmada
5. `atencion_especial` - Consultas técnicas/problemas
6. `pedido_reunion` - Solicitud de videollamada/reunión

### Características Actuales
- ✅ Clasificación automática con 6 categorías
- ✅ Sistema de confianza (0-100%)
- ✅ Escalamiento inteligente a humano
- ✅ Memoria conversacional (20 mensajes)
- ✅ Prompt extenso y bien estructurado para ventas mayoristas
- ✅ Manejo de categoría anterior (evita cambios en mensajes ambiguos)

---

## 🎯 Funcionalidades Identificadas para Integración

### 🥇 Prioridad Alta (Impacto Inmediato)

#### 1. Filtro Etiqueta "Humano"
- **Beneficio**: Evitar que bot y humano respondan simultáneamente
- **Complejidad**: 🟢 Muy Baja
- **Tiempo estimado**: 10 minutos
- **Estado**: ✅ **COMPLETADO** (2025-11-18)
- **Detalles**:
  - Verificar si conversación tiene label "humano" antes de procesar
  - Si tiene label → detener workflow
  - Si no tiene label → continuar flujo normal
- **Implementación**:
  - Añadido nodo "Filter" después de "Obtener Labels Actuales"
  - Condición: `labels NOT CONTAINS "humano"`
  - Si tiene etiqueta "humano", el workflow se detiene automáticamente

#### 2. Procesamiento de Mensajes de Voz
- **Beneficio**: Soporte completo de comunicación (muchos usuarios prefieren audio)
- **Complejidad**: 🟢 Baja
- **Tiempo estimado**: 20 minutos
- **Estado**: ⏳ Pendiente
- **Componentes**:
  - Detectar tipo de mensaje (texto/audio)
  - Extraer base64 del audio
  - Convertir a archivo .mp3
  - Transcribir con OpenAI Whisper
  - Normalizar texto transcrito
- **Dependencias**: OpenAI API (Whisper)

#### 3. Memoria Postgres Persistente
- **Beneficio**: Mantener contexto entre sesiones, no se pierde historial
- **Complejidad**: 🟢 Baja
- **Tiempo estimado**: 30 minutos
- **Estado**: ✅ **COMPLETADO** (2025-11-18)
- **Cambio**: Reemplazar Buffer Window Memory por Postgres Chat Memory
- **sessionKey**: Usar source_id de Chatwoot
- **Implementación**:
  - Reemplazado nodo "Simple Memory" (Buffer Window) por "Postgres Chat Memory"
  - Configurado con credenciales de EasyPanel Postgres
  - Host: `alvaro_postgres`, Database: `alvaro`, Port: `5432`
  - Mantiene sessionKey: `body.conversation.contact_inbox.source_id`
  - Ahora la memoria persiste entre sesiones (no solo 20 mensajes)

### 🥈 Prioridad Media (Diferenciador Competitivo)

#### 4. Sistema de Formateo Multi-Parte
- **Beneficio**: Respuestas naturales divididas en mensajes cortos (estilo WhatsApp/humano)
- **Complejidad**: 🟡 Media
- **Tiempo estimado**: 1 hora
- **Estado**: ⏳ Pendiente
- **Componentes**:
  - Chain LLM con GPT-4.1-mini (temp 0.3)
  - Structured Output Parser (JSON con part_1, part_2, part_3, part_4)
  - Auto-fixing Output Parser
  - Reglas: máx 4 partes, 2 frases/parte, 1 emoji/parte
- **Output esperado**:
```json
{
  "response": {
    "part_1": "Primera parte...",
    "part_2": "Segunda parte (si necesaria)",
    "part_3": "Tercera parte (opcional)",
    "part_4": "Cuarta parte (opcional)"
  }
}
```

#### 5. Envío Escalonado de Respuestas
- **Beneficio**: Simula escritura humana real, experiencia premium
- **Complejidad**: 🟡 Media
- **Tiempo estimado**: 1 hora
- **Estado**: ⏳ Pendiente
- **Componentes**:
  - Wait nodes con delays calculados
  - If conditions para verificar existencia de cada parte
  - Envío secuencial: part_1 → wait → part_2 → wait → part_3 → wait → part_4
- **Delay sugerido**: 30ms por carácter o fijo de 2-3 segundos

### 🥉 Prioridad Media-Baja (Optimización)

#### 6. Sistema Anti-Spam Redis
- **Beneficio**: Evita interrumpir al cliente, espera a que termine de escribir
- **Complejidad**: 🟡 Media
- **Tiempo estimado**: 1-2 horas
- **Estado**: ⏳ Pendiente
- **Lógica**:
  - Guardar mensaje en cola Redis (por número/user)
  - Recuperar historial
  - Validar si último mensaje tiene >7 segundos
  - Si <7 segs → Wait 7 segundos → volver a validar
  - Si >7 segs → procesar
  - Si sessionID diferente → ignorar (duplicado)
- **Dependencias**: Redis database
- **Nota**: Chatwoot puede tener rate limiting propio, verificar si es necesario

### 🎨 Prioridad Baja (Datos y Analytics)

#### 7. Subagente CRM con Airtable
- **Beneficio**: Base de datos automática de clientes, seguimiento, remarketing
- **Complejidad**: 🟡 Media
- **Tiempo estimado**: 2 horas
- **Estado**: ⏳ Pendiente
- **Funciones**:
  - Consultar contactos existentes (por email/teléfono)
  - Crear nuevos contactos
  - Actualizar información (evitar duplicados)
  - Campos: Nombre, Email, Teléfono, Origen: "Chatwoot", Categoría, Notas
- **Dependencias**: Airtable account + base de datos configurada
- **Modelo sugerido**: GPT-4.1-mini

#### 8. Base de Conocimiento RAG (Supabase)
- **Beneficio**: Consultas semánticas sobre catálogo extenso, respuestas precisas
- **Complejidad**: 🔴 Alta
- **Tiempo estimado**: 3-4 horas
- **Estado**: ⏳ Pendiente
- **Componentes**:
  - Supabase Vector Store
  - OpenAI Embeddings (text-embedding-ada-002)
  - Tabla: documentos_empresa
  - Function: match_documentos_empresa
  - Carga de documentos: catálogo, políticas, FAQ
- **Dependencias**: Supabase account, documentos de XIMARO
- **Nota**: Evaluar si el prompt actual es suficiente o si se necesita base vectorial

### 🚀 Funcionalidades Custom XIMARO (Futuro)

#### 9. Subagente Cotizaciones Automáticas
- **Beneficio**: Generar presupuestos al instante
- **Complejidad**: 🔴 Alta (depende de sistema de precios)
- **Estado**: 💡 Idea
- **Requisitos**:
  - API/DB de productos y precios
  - Lógica de descuentos por volumen
  - Formato de cotización

#### 10. Subagente Consulta de Stock
- **Beneficio**: Informar disponibilidad en tiempo real
- **Complejidad**: 🟡 Media-Alta (depende de inventario)
- **Estado**: 💡 Idea
- **Requisitos**:
  - API/DB de inventario
  - Integración con sistema de stock

#### 11. Subagente Tracking de Pedidos
- **Beneficio**: Estado de envío en tiempo real
- **Complejidad**: 🟡 Media-Alta
- **Estado**: 💡 Idea
- **Requisitos**:
  - Integración con Vía Cargo / Andreani
  - DB de pedidos

---

## 📅 Plan de Implementación Propuesto

### Fase 1: Mejoras Rápidas ⚡ (1-2 horas)
**Objetivo**: Impacto inmediato con cambios sencillos

- [ ] 1. Filtro etiqueta "humano" (10 min)
- [ ] 2. Procesamiento de voz con Whisper (20 min)
- [ ] 3. Memoria Postgres persistente (30 min)

**Resultado esperado**: Bot más robusto, multicanal, con mejor memoria

---

### Fase 2: Humanización 🎭 (2-3 horas)
**Objetivo**: Diferenciador competitivo, experiencia premium

- [ ] 4. Sistema de formateo multi-parte (1 hora)
- [ ] 5. Envío escalonado de respuestas (1 hora)

**Resultado esperado**: Conversación ultra-natural, parece persona real

---

### Fase 3: Inteligencia Anti-Spam 🛡️ (1-2 horas)
**Objetivo**: Evitar interrupciones, mejor UX

- [ ] 6. Sistema anti-spam Redis (1-2 horas)

**Resultado esperado**: Bot espera a que cliente termine de escribir

---

### Fase 4: Datos y CRM 💾 (2-4 horas)
**Objetivo**: Base de clientes, seguimiento, remarketing

- [ ] 7. Subagente CRM con Airtable (2 horas)
- [ ] 8. Base RAG Supabase (3-4 horas) - Opcional

**Resultado esperado**: CRM automático, mejores respuestas técnicas

---

### Fase 5: Custom XIMARO 🚀 (Futuro)
**Objetivo**: Funcionalidades específicas del negocio

- [ ] 9. Subagente cotizaciones
- [ ] 10. Subagente stock
- [ ] 11. Subagente tracking

**Resultado esperado**: Automatización completa end-to-end

---

## ✅ Progreso de Implementación

### Sprint Actual: **Fase 1 - Mejoras Rápidas** ✅ COMPLETADO
**Inicio**: 2025-11-18
**Fin**: 2025-11-18
**Duración real**: ~1 hora

#### Tareas Completadas
- ✅ Análisis automatización actual XIMARO
- ✅ Análisis automatización referencia (Peluquería)
- ✅ Identificación de funcionalidades a integrar
- ✅ Creación de documento de progreso (lumichat.md)
- ✅ **Obtención de credenciales Postgres y Redis desde EasyPanel**
- ✅ **Implementación filtro etiqueta "humano"**
- ✅ **Migración de Buffer Memory a Postgres Chat Memory**
- ✅ **Creación de workflow mejorado: `ximaro-fase1-mejorado.json`**

#### Archivos Generados
1. `/home/user/lumichat/workflows/ximaro-original.json` - Workflow original
2. `/home/user/lumichat/workflows/ximaro-fase1-mejorado.json` - **Workflow con Fase 1 implementada**
3. `/home/user/lumichat/lumichat.md` - Documentación del proyecto (este archivo)

#### Cambios Realizados en Fase 1

**🔹 Nuevo nodo: "Filtro: No tiene etiqueta 'humano'"**
- **Tipo**: Filter (n8n-nodes-base.filter)
- **Posición**: Después de "Obtener Labels Actuales"
- **Condición**: `labels NOT CONTAINS "humano"`
- **Beneficio**: Si un humano ya está atendiendo (etiqueta "humano" presente), el bot NO responde

**🔹 Nodo actualizado: "Postgres Chat Memory"**
- **Tipo**: memoryPostgresChat (antes: memoryBufferWindow)
- **Host**: `alvaro_postgres`
- **Database**: `alvaro`
- **User**: `postgres`
- **Port**: `5432`
- **sessionKey**: `body.conversation.contact_inbox.source_id`
- **Beneficio**: Memoria persistente ilimitada (no solo 20 mensajes)

**🔹 Flujo actualizado**:
```
Webhook → If (no outgoing) → Extraer Conversation ID →
Obtener Labels Actuales → 🆕 Filtro Humano → Configuración →
AI Agent (Gemini + 🆕 Postgres Memory) → Extraer Clasificación →
Enviar Respuesta → Aplicar Etiqueta → ¿Escalar a Humano?
```

#### Tareas Pendientes (Próxima Fase)
- ⏳ Procesamiento de mensajes de voz (requiere OpenAI API)
- ⏳ Decisión sobre próxima fase (Fase 2: Humanización o Fase 3: Anti-spam)

#### Bloqueadores
- **Procesamiento de voz**: Requiere OpenAI API key (Whisper)
- **Fases avanzadas**: Decisión del cliente sobre prioridades

---

## 🔧 Configuración y Dependencias

### Servicios Actuales
- ✅ Chatwoot (alvaro-chatwoot.5epeub.easypanel.host)
- ✅ Google Gemini API
- ✅ n8n instance
- ✅ **Postgres database (EasyPanel) - CONFIGURADO**
- ✅ **Redis database (EasyPanel) - CONFIGURADO**

### Servicios Necesarios (según funcionalidades futuras)
- ⏳ OpenAI API (para Whisper, GPT-4.1-mini, embeddings) - Fase 2+
- ⏳ Airtable account (para CRM) - Opcional Fase 4
- ⏳ Supabase account (para RAG) - Opcional Fase 4

### Credenciales Configuradas ✅
- [x] **Postgres connection** - Host: `alvaro_postgres`, DB: `alvaro`, Port: `5432`
- [x] **Redis connection** - Host: `alvaro_redis`, Port: `6379`
- [x] Chatwoot API Token

### Credenciales Pendientes
- [ ] OpenAI API Key (para voz + fases avanzadas)
- [ ] Airtable API key (si se usa CRM)
- [ ] Supabase API key + project URL (si se usa RAG)

---

## 📝 Notas y Decisiones

### Decisiones Pendientes
1. **¿Qué funcionalidades implementar primero?**
   - Recomendación: Empezar con Fase 1 o Fase 2

2. **¿Tienes acceso a Redis?**
   - Necesario para anti-spam (Fase 3)

3. **¿Tienes acceso a Postgres?**
   - Necesario para memoria persistente (Fase 1)

4. **¿Quieres usar Airtable como CRM?**
   - Alternativas: Google Sheets, base SQL propia

5. **¿Tienes documentación extensa de productos?**
   - Evaluar si necesitas RAG o prompt actual es suficiente

6. **¿Qué funcionalidades custom de XIMARO son prioritarias?**
   - Cotizaciones automáticas
   - Consulta de stock
   - Tracking de pedidos
   - Otras

### Notas Técnicas
- La automatización actual usa `conversation.contact_inbox.source_id` como sessionKey
- Categoría anterior se usa para evitar cambios en mensajes cortos/ambiguos
- Sistema de confianza ayuda a decidir escalamiento
- Prompt muy completo, incluye políticas, productos, flujo conversacional

### Ideas Adicionales
- Considerar integración con sistema de facturación de XIMARO
- Posible integración con WhatsApp Business API (futuro)
- Analytics de conversaciones para mejorar prompt
- A/B testing de respuestas

---

## 🔗 Referencias

### Archivos del Proyecto
- `[ruta_json_ximaro]` - Automatización actual XIMARO
- `[ruta_json_peluqueria]` - Automatización referencia

### Documentación Relevante
- [n8n Docs](https://docs.n8n.io/)
- [Chatwoot API](https://www.chatwoot.com/docs/product/channels/api/client-apis)
- [OpenAI API](https://platform.openai.com/docs)
- [Airtable API](https://airtable.com/developers/web/api/introduction)

---

## 📞 Contacto y Soporte

**Cliente**: XIMARO
**Desarrollador**: [Tu nombre/equipo]
**Branch de trabajo**: `claude/n8n-json-automation-01F1fjhhCyNYQVqJLQzUpiB4`

---

**Última actualización**: 2025-11-18
**Versión del documento**: 1.0
