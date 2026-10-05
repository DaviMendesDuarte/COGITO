# 🚀 Pipeline de CI/CD Profissional - COGITO

Este documento descreve a arquitetura, o funcionamento e as diretrizes operacionais do pipeline de **Integração Contínua (CI)** e **Entrega Contínua (CD)** do projeto **COGITO** (aplicativo Flutter/Android).

---

## 📑 Sumário
1. [Visão Geral e Arquitetura](#visão-geral-e-arquitetura)
2. [Workflow de CI: Quality Gate](#workflow-de-ci-quality-gate)
3. [Workflow de CD: Entrega e Distribuição](#workflow-de-cd-entrega-e-distribuição)
4. [Segurança e Boas Práticas (Repositório Público)](#segurança-e-boas-práticas-repositório-público)
5. [Configuração de Proteção de Branch (Branch Protection)](#configuração-de-proteção-de-branch-branch-protection)
6. [Configuração de Assinatura de Produção Android (Keystore)](#configuração-de-assinatura-de-produção-android-keystore)
7. [Diagnóstico de Falhas Comuns](#diagnóstico-de-falhas-comuns)

---

## 🏗️ Visão Geral e Arquitetura

O ciclo de vida do código no COGITO segue o padrão desacoplado de duas fases:

```
[Desenvolvedor]
       │
       ▼
[Branch de Feature/Bugfix] ──► [Pull Request para main/develop]
                                       │
                                       ▼
                       ┌──────────────────────────────┐
                       │      COGITO CI PIPELINE      │
                       │  - Format check (dart format)│
                       │  - Lint/Analyze (flutter)    │
                       │  - Security Scan (Gitleaks)  │
                       │  - Unit Tests & Coverage     │
                       │  - Build Check (Android)     │
                       │  - Quality Gate Consolidado  │
                       └──────────────┬───────────────┘
                                      │ Aprovado
                                      ▼
                           [Merge na branch main]
                                      │
                                      ▼
                       ┌──────────────────────────────┐
                       │      COGITO CD PIPELINE      │
                       │  - Setup Java 17 & Flutter   │
                       │  - Gradle Cache              │
                       │  - Injeção de Keystore/Assin.│
                       │  - Build Release APK / AAB   │
                       │  - Geração de Checksum SHA256│
                       │  - Upload de Artefatos       │
                       │  - GitHub Release (Tags v*)  │
                       └──────────────────────────────┘
```

---

## 🧪 Workflow de CI: Quality Gate

Arquivo: `.github/workflows/ci.yml`

### Quando Executa
- Em todo **Pull Request** direcionado às branches `main` e `develop`.
- Em todo **Push** realizado em branches `main`, `develop`, `feature/**`, `bugfix/**` e `release/**`.

### Jobs Executados em Paralelo e Sequência
1. **🎨 Qualidade de Código & Lint (`code-quality`)**:
   - Valida a formatação estrita do código através de `dart format --output=none --set-exit-if-changed .`.
   - Executa análise estática com `flutter analyze` identificando inconsistências e violações de regras.
2. **🛡️ Auditoria de Segurança (`security-audit`)**:
   - Varredura de histórico e commits utilizando **Gitleaks** para prevenir vazamentos acidentais de tokens, senhas ou chaves privadas.
3. **⚡ Testes Unitários & Cobertura (`unit-tests`)**:
   - Executa a suíte de testes unitários com medição de cobertura (`flutter test --coverage`).
   - Publica o relatório LCOV (`coverage/lcov.info`) como artefato por 7 dias.
4. **🏗️ Validação de Build (`build-check`)**:
   - Compila uma versão rápida de verificação (`flutter build apk --debug`), garantindo que o Gradle, dependências e código Kotlin/Android integrem sem quebras.
5. **🎯 Quality Gate (`quality-gate`)**:
   - Job agregador que avalia o resultado de todas as etapas anteriores. Se qualquer verificação falhar, o Quality Gate bloqueia o pipeline e impede o merge.

---

## 🚀 Workflow de CD: Entrega e Distribuição

Arquivo: `.github/workflows/cd.yml`

### Quando Executa
- **Automático no Push da `main`**: Gera os artefatos de entrega contínua (Release APK) para homologação interna e testes.
- **Automático em Tags de Versão (`v*`)**: Gera o Release APK e o Android App Bundle (AAB), calculando checksums e publicando automaticamente uma **GitHub Release**.
- **Manual (`workflow_dispatch`)**: Permite que desenvolvedores autorizados disparem builds sob demanda, escolhendo entre `apk`, `bundle` ou `both`, com opção de publicar release diretamente.

### Artefatos e Integridade
- **`cogito-android-release-apk`**: Pacote APK pronto para instalação direta em dispositivos de teste (retenção de 14 dias).
- **`cogito-android-release-bundle`**: Pacote AAB otimizado para publicação na Google Play Store (retenção de 14 dias).
- **`cogito-build-checksums`**: Arquivo `SHA256SUMS.txt` com as assinaturas criptográficas de cada binário gerado, assegurando rastreabilidade e integridade.

---

## 🔐 Segurança e Boas Práticas (Repositório Público)

> [!CAUTION]
> Como este repositório é **público**, qualquer artefato publicado em GitHub Releases e qualquer log emitido nas Actions fica acessível publicamente.

1. **Credenciais e Keystores**:
   - O repositório possui regras no `.gitignore` impedindo o commit de `.jks`, `.keystore`, `key.properties` e arquivos `.env`.
   - As credenciais de assinatura **NUNCA** devem ser commitadas. Elas devem ser injetadas exclusivamente através de **GitHub Secrets**.
2. **Fallback Seguro**:
   - Caso as secrets de assinatura de produção não estejam configuradas, o CD compila com assinatura de desenvolvimento/teste e emite um aviso explícito no resumo da execução, sem interromper o fluxo de validação contínua.
3. **Princípio do Menor Privilégio**:
   - O CI roda com permissões estritamente restritas de leitura (`contents: read`).
   - O CD utiliza `contents: write` apenas no job de release oficial para permitir anexar os binários compilados.

---

## 🛡️ Configuração de Proteção de Branch (Branch Protection)

Para garantir que nenhuma alteração entre na branch `main` sem passar pelo Quality Gate, siga os passos abaixo no GitHub:

1. Acesse o repositório no GitHub: **https://github.com/DaviMendesDuarte/COGITO_CICD**.
2. Vá em **Settings** > **Branches**.
3. Na seção **Branch protection rules**, clique em **Add branch ruleset** (ou **Add rule**).
4. Configure os seguintes campos:
   - **Branch name pattern**: `main`
   - Marque: **Require a pull request before merging**.
   - Marque: **Require status checks to pass before merging**.
   - Na barra de busca de checks, selecione:
     - `Quality Gate`
   - Marque: **Require branches to be up to date before merging**.
   - Marque: **Do not allow bypassing the above settings**.
5. Clique em **Save changes**.

A partir deste momento, nenhum desenvolvedor (mesmo administradores) conseguirá enviar código que quebre compilação, formatação ou testes diretamente na branch principal.

---

## 🔑 Configuração de Assinatura de Produção Android (Keystore)

Para gerar builds oficiais assinados para a Google Play Store:

1. Gere seu keystore de release localmente (ou use um existente):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Converta o arquivo `.jks` para base64:
   - No Windows (PowerShell):
     ```powershell
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
     ```
   - No Linux/macOS:
     ```bash
     base64 -w 0 upload-keystore.jks
     ```
3. Acesse o repositório no GitHub > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**:
   - `KEYSTORE_BASE64`: Conteúdo base64 do arquivo `.jks`.
   - `KEYSTORE_PASSWORD`: Senha do keystore.
   - `KEY_ALIAS`: Alias da chave (ex: `upload`).
   - `KEY_PASSWORD`: Senha da chave.

---

## 🛠️ Diagnóstico de Falhas Comuns

| Erro / Sintoma | Causa Mais Comum | Resolução |
| :--- | :--- | :--- |
| **Falha em `dart format`** | Arquivo `.dart` fora do padrão oficial de indentação. | Execute `dart format .` na raiz do projeto e envie as alterações. |
| **Falha em `flutter analyze`** | Sintaxe inválida, import não utilizado ou erro de tipagem. | Execute `flutter analyze` localmente para ver os alertas e corrija-os. |
| **Falha no `security-audit`** | Gitleaks detectou string semelhante a token, chave privada ou senha. | Remova a credencial do código e do histórico; utilize GitHub Secrets ou variáveis de ambiente. |
| **Falha em `unit-tests`** | Regra de negócio alterada ou teste desatualizado. | Execute `flutter test` localmente e ajuste a regra ou o caso de teste. |
| **Falha em `build-check`** | Erro de compilação no Gradle, incompatibilidade de SDK ou dependência nativa quebrada. | Verifique se `android/app/build.gradle.kts` e as dependências no `pubspec.yaml` estão sincronizadas. |
