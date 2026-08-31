# =============================================================================
# test_utils.R
# Testes simples das funções utilitárias (src/01_utils.R).
#
# Uso (a partir da raiz do repositório):
#   Rscript tests/test_utils.R
# =============================================================================

source("src/00_config.R")
source("src/01_utils.R")

check <- function(condicao, rotulo) {
  if (isTRUE(condicao)) {
    cat(sprintf("[OK] %s\n", rotulo))
  } else {
    stop(sprintf("[FALHOU] %s", rotulo))
  }
}

# --- normalizar_cid ---------------------------------------------------------
check(normalizar_cid("q21.3") == "Q213", "normalizar_cid minúsculas e pontuação")
check(normalizar_cid("Q248Q539Q909") == "Q248Q539Q909", "normalizar_cid preserva concatenação")

# --- extrair_codigos_q ------------------------------------------------------
check(identical(extrair_codigos_q("Q224Q233Q253Q891"), list(c("Q224", "Q233", "Q253", "Q891"))),
      "extrair_codigos_q extrai múltiplos códigos")

# --- tem_cid_q20_q28 (correção do bug de ancoragem) -------------------------
check(tem_cid_q20_q28("Q213") == TRUE, "Q213 é cardíaco")
check(tem_cid_q20_q28("Q031Q248") == TRUE, "cardíaco em posição != 1 é detectado")
check(tem_cid_q20_q28("Q909Q891") == FALSE, "nenhum cardíaco retorna FALSE")
check(identical(tem_cid_q20_q28(NA_character_), FALSE), "NA retorna FALSE")
check(identical(tem_cid_q20_q28(c("Q213", "Q031Q248", "Q909", NA)),
                c(TRUE, TRUE, FALSE, FALSE)), "vetor misto")

# --- verificar_colunas ------------------------------------------------------
df_teste <- data.frame(a = 1, b = 2)
check(isTRUE(verificar_colunas(df_teste, c("a", "b"), "teste")), "verificar_colunas ok")
erro <- tryCatch({ verificar_colunas(df_teste, "c", "teste"); FALSE },
                 error = function(e) TRUE)
check(erro, "verificar_colunas sinaliza coluna ausente")

cat("\nTodos os testes passaram.\n")
