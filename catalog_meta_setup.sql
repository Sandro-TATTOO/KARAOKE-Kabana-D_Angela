-- catalog_meta_setup.sql
-- Tabela de metadados do catálogo (versão). Permite ao app checar se há
-- atualização com 1 request leve por abertura, em vez de baixar tudo sempre.
-- Execute no SQL Editor do Supabase.

CREATE TABLE IF NOT EXISTS public.catalog_meta (
  id          BIGSERIAL PRIMARY KEY,
  version     INT NOT NULL DEFAULT 1,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Garante ao menos uma linha.
INSERT INTO public.catalog_meta (version)
SELECT 1
WHERE NOT EXISTS (SELECT 1 FROM public.catalog_meta);

-- RLS: leitura pública.
ALTER TABLE public.catalog_meta ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalog_meta_select_public" ON public.catalog_meta;
CREATE POLICY "catalog_meta_select_public"
  ON public.catalog_meta
  FOR SELECT
  USING (true);

GRANT SELECT ON public.catalog_meta TO anon, authenticated;

-- (Opcional) Bump automático da versão quando songs mudar.
CREATE OR REPLACE FUNCTION public.bump_catalog_version()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.catalog_meta SET version = version + 1, updated_at = now()
  WHERE id = (SELECT id FROM public.catalog_meta ORDER BY id LIMIT 1);
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_songs_bump_version ON public.songs;
CREATE TRIGGER trg_songs_bump_version
  AFTER INSERT OR UPDATE OR DELETE ON public.songs
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.bump_catalog_version();
