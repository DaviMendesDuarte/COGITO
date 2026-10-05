# RELATÓRIO TÉCNICO DE SEGURANÇA DA INFORMAÇÃO E PROTEÇÃO DE DADOS

**Plataforma COGITO: Controle de Orçamentos e Gestão Inteligente, Técnico e Objetivo**  
**Autores:** Davi Mendes Duarte e Equipe de Desenvolvimento COGITO  
**Ecossistema:** Mobile Multiplataforma (Flutter / Dart) & Cloud Backend Serverless (Firebase)  
**Data:** 2026  

---

## 1. INTRODUÇÃO E ESCOPO DO SISTEMA

O presente relatório tem como finalidade descrever de forma técnica, clara, exaustiva e estruturada a arquitetura de segurança da informação e proteção de dados implementada no ecossistema e aplicativo do **COGITO** (*Controle de Orçamentos e Gestão Inteligente, Técnico e Objetivo*). A plataforma consiste em uma solução móvel completa voltada à gestão financeira pessoal, permitindo autenticação segura de usuários (via credenciais dedicadas ou federação Google), categorização e rastreamento de transações financeiras (receitas, despesas e transferências), criação de orçamentos parametrizados, planejamento de metas e caixinhas de poupança, controle de contas bancárias e cartões de crédito, bem como a consultoria financeira personalizada fornecida pelo assistente inteligente **CONRADO**, dotado de integração à IA generativa em nuvem e algoritmo de inteligência contextual de contingência local.

Diante da natureza extremamente sensível das operações realizadas na plataforma — que envolvem o tratamento contínuo de informações cadastrais, fluxos de renda, salários, proventos trabalhistas, dados bancários e comunicações privadas do usuário —, a segurança da informação foi estabelecida como um pilar arquitetural inegociável desde a primeira linha de código (*Security by Design* e *Privacy by Design*). As seções a seguir detalham todas as etapas, camadas e mecanismos técnicos adotados para garantir a confidencialidade, a integridade, a autenticidade, a disponibilidade e o estrito cumprimento da legislação de privacidade (LGPD) em todo o ciclo de vida dos dados manipulados pelo sistema.

---

## 2. ETAPAS E MECANISMOS DE SEGURANÇA IMPLEMENTADOS

O sistema do COGITO adota uma estratégia de defesa em profundidade (*Defense in Depth*), distribuída em múltiplas camadas de proteção que cobrem desde a interface com o usuário até o tráfego de rede, processamento em memória, persistência em banco de dados NoSQL em nuvem e esteira automatizada de entrega contínua (CI/CD). A seguir, detalham-se as etapas de segurança presentes na solução:

### Etapa 1: Validação Rigorosa, Sanitização de Dados de Entrada e Tipagem Estrita (*Type Safety*)
Todos os dados submetidos pelo usuário nos formulários de cadastro, edição de perfil, registro de transações, criação de metas ou envio de mensagens passam por uma triagem defensiva imediata antes de qualquer persistência ou consulta aos serviços em nuvem:
* **Higienização Sistemática e Trimming de Strings:** Aplicação compulsória de corte de espaços em branco ociosos (`.trim()`) e sanitização de caracteres especiais em campos de e-mail, senhas, descrições financeiras e nomes, prevenindo comportamentos anômalos, quebra de formatação e injeção de caracteres de controle invisíveis.
* **Validação Sintática Estrita de E-mail via Expressões Regulares:** Utilização de padrões Regex formais para aferir se os endereços eletrônicos informados respeitam a estrutura canônica de provedores de correio eletrônico (`user@domain.com`), mitigando o cadastramento de entradas malformadas nos fluxos de registro e de redefinição de senha.
* **Tipagem Estrita e Type Casting Defensivo:** O ecossistema Dart impõe tipagem forte em tempo de compilação. Todos os valores monetários são rigidamente manipulados como `double`, contadores e idades como `int`, e carimbos temporais como `DateTime` ou `FieldValue.serverTimestamp()`, impossibilitando ataques de confusão de tipos (*type confusion*) ou adulteração de payloads via injeção de tipos inconsistentes.
* **Validação de Limites Aritméticos em Finanças:** Operações que envolvem montantes monetários (receitas, despesas, salários e metas) possuem verificações de borda obrigatórias no client-side e nas regras de negócio, bloqueando valores negativos arbitrários ou extrapolados que poderiam corromper balanços contábeis.

### Etapa 2: Autenticação Biométrica Nativa e Detecção de Dispositivo Físico
O COGITO oferece mecanismos modernos de autenticação de ponta no dispositivo móvel, reduzindo a exposição a clonagens e invasões em dispositivos comprometidos:
* **Autenticação Biométrica Nativa (`BiometricService`):** Integração com a biblioteca de baixo nível `local_auth`, permitindo que o usuário proteja a abertura do aplicativo e o acesso aos dados financeiros por meio de leitura biométrica (impressão digital ou reconhecimento facial nativo do sistema operacional Android/iOS), com a flag `biometricOnly: true` para impedir desvios por senhas simples de bloqueio.
* **Detecção Defensiva de Hardware vs. Emulador (`device_info_plus`):** O método `isDispositivoFisico()` inspeciona os atributos do hardware subjacente do dispositivo (`androidInfo.isPhysicalDevice` e `iosInfo.isPhysicalDevice`). Caso a aplicação seja executada em emuladores ou ambientes virtualizados não autorizados, salvaguardas adicionais podem ser aplicadas para prevenir a execução de testes automatizados de força bruta por atacantes externos.

### Etapa 3: Gestão Segura de Credenciais e Autenticação Federada (OAuth2)
A custódia das credenciais dos usuários adota padrões internacionais de alta segurança, assegurando que senhas nunca sejam armazenadas ou trafegadas em formato de texto simples:
* **Delegação Criptográfica ao Firebase Authentication:** A autenticação por e-mail e senha é delegada à infraestrutura de alta confiabilidade da Google, que utiliza algoritmos robustos de derivação de chave e funções hash criptográficas unidirecionais com geração automática de salt por usuário, tornando o banco imune a ataques de tabelas pré-computadas (*rainbow tables*).
* **Autenticação Federada com Google Sign-In (OAuth2):** Implementação do fluxo de credenciamento via Google Identity Services (`GoogleSignIn`), autenticando o titular por meio de tokens criptográficos de acesso e de identidade (`accessToken` e `idToken`), sem que o COGITO precise manipular ou armazenar credenciais diretas do usuário.
* **Expurgo Preventivo de Senhas em Memória:** Nenhuma senha digitada permanece armazenada em variáveis globais ou controladores estáticos após o envio e validação junto ao provedor de autenticação.

### Etapa 4: Gerenciamento de Sessão, Reativação e Reautenticação Sensível (*Step-up Authentication*)
O acesso às áreas restritas do aplicativo segue um ciclo de vida rigorosamente monitorado:
* **Monitoramento Contínuo de Estado (`authStateChanges`):** O aplicativo escuta de forma reativa a stream do `FirebaseAuth`. Mudanças no status de credenciais, desativações remotas de conta ou tokens revogados forçam o encerramento imediato do ciclo de acesso no aplicativo.
* **Reautenticação Obrigatória para Ações Críticas:** Para operações com alto impacto na privacidade e segurança — como a exclusão definitiva da conta (`excluirContaEConteudo`) ou alteração de dados sensíveis —, o sistema exige *Step-up Authentication* (revalidação síncrona de senha no caso de provedor de e-mail ou renovação da credencial Google). Se a checagem falhar, a operação é rejeitada categoricamente antes de atingir o banco de dados.
* **Destruição Completa de Sessão (`signOut`):** Ao realizar o logout, a aplicação encerra as sessões no `_googleSignIn` e no `_firebaseAuth`, além de purgar integralmente o mapa em memória `FirebaseFirestoreService.usuarioLogado = null`, impossibilitando o acesso por cache residual de memória.

### Etapa 5: Controle de Acesso e Prevenção contra Acesso Indevido a Recursos (Mitigação de IDOR / BOLA)
A vulnerabilidade de referência direta e insegura a objetos (*Insecure Direct Object Reference* - IDOR / BOLA) é mitigada através da amarração lógica mandatória entre a identidade do usuário autenticado e os documentos manipulados:
* **Isolamento de Dados por UID (`id_cliente`):** Todas as entidades financeiras registradas no Cloud Firestore (transações, metas, cartões, contas bancárias, históricos de chat e orçamentos) possuem como chave primária de posse o identificador exclusivo `id_cliente == uid`.
* **Filtragem Compulsória em Consultas:** As rotinas de busca no banco de dados aplicam cláusulas estritas vinculando a consulta exclusivamente ao identificador do titular ativo (`.where('id_cliente', isEqualTo: idClienteAtual)`), impedindo que a requisição de um usuário comprometa ou liste registros pertencentes a outro titular.

### Etapa 6: Blindagem contra Injeção de Código em Banco de Dados (Mitigação de NoSQL / SQL Injection)
Historicamente, a injeção de comandos SQL ou NoSQL figura entre as vulnerabilidades mais danosas em sistemas web e móveis. No COGITO, a proteção é nativa e absoluta:
* **Arquitetura Serverless Baseada em SDK Oficial do Cloud Firestore:** O COGITO utiliza as APIs parametrizadas do Firebase SDK, eliminando comandos textuais concatenados. As entradas de dados são tratadas exclusivamente como nós literais e dados tipados em mapas JSON/Protobuf, neutralizando qualquer vetor de injeção sintática de comandos.
* **Tratamento de Exceções e Ocultação de Stack Traces:** O aplicativo intercepta falhas de rede e erros de regras de banco via blocos `try-catch` estruturados, emitindo mensagens polidas e inteligíveis para o usuário e prevenindo a exibição de esquemas de coleções, identificadores de projetos ou detalhes internos do banco de dados na interface.

### Etapa 7: Criptografia Aplicada, Integridade de Identificadores e Proteção de Perfil
A gestão de identidade visual do perfil do usuário utiliza criptografia simétrica com verificação de integridade proprietária (`ProfilePhotoHelper`):
* **Assinatura Criptográfica com Salt e Versionamento de Algoritmo:** O identificador da imagem de perfil padrão institucional é cifrado através da combinação de um salt secreto (`COGITO_SECURE_KEY_2026_AVATAR`), codificação em bytes UTF-8 e encapsulamento em Base64 precedido pelo prefixo de versão `enc_v1_`.
* **Resiliência a Adulterações e Injeções Arbitrárias:** O decodificador valida rigorosamente a integridade da assinatura antes de aceitar qualquer parâmetro. Tentativas de falsificação, hashes truncados ou adulterados são sumariamente rejeitados retornando `null`, neutralizando ataques de injeção ou referências a arquivos maliciosos.
* **Eliminação da Superfície de Ataque de Upload Arbitrário:** O aplicativo padroniza avatares institucionais estáticos incorporados nos assets seguros do pacote, extinguindo completamente os riscos clássicos de upload de executáveis maliciosos, estouro de armazenamento e ataques de travessia de diretório (*Path Traversal*).

### Etapa 8: Integridade Transacional e Consistência Financeira (Propriedades ACID)
Operações que envolvem concorrência ou alterações de múltiplos documentos financeiros recebem salvaguardas especiais:
* **Escritas Atômicas e Lotes (`WriteBatch`):** Atualizações de múltiplos registros (como cálculo de saldo de contas, vinculação de movimentações e amortização de orçamentos) são organizadas de modo a preservar a integridade referencial dos lançamentos contábeis.
* **Carimbos Temporais Confiáveis no Servidor:** As transações utilizam `FieldValue.serverTimestamp()` para auditoria, garantindo que o carimbo de data/hora não seja manipulado pelo relógio local do smartphone do usuário.

### Etapa 9: Salvaguardas Éticas, Engenharia de Prompt e Segurança na Camada de IA (Assistente CONRADO)
O assistente inteligente CONRADO conta com salvaguardas arquiteturais que protegem a interação do usuário e evitam respostas nocivas ou fora de conformidade (`ConradoApiService`):
* **Salvaguarda Ética e Repúdio a Ofensas:** O assistente possui um filtro heurístico prévio e instruções de sistema rigorosas que identificam termos de baixo calão, agressões verbais e linguagem depreciativa. Em tais situações, o CONRADO suspende o atendimento, manifesta indignação institucional através de emoji específico (😤) e condiciona a continuidade da consulta a uma postura respeitosa.
* **Restrição Rígida ao Domínio Financeiro Pessoal:** Para evitar desvio de finalidade (*jailbreak* ou alucinações temáticas), o CONRADO recusa categoricamente dúvidas alheias a finanças pessoais, declarando expressamente seu escopo especializado dentro do COGITO.
* **Motor Contextual de Contingência Offline:** O assistente dispõe de uma base local embutida para fornecimento de cálculos e orientações financeiras e trabalhistas de alta precisão (como 13º Salário, Saque-Aniversário do FGTS, Férias CLT e Reserva de Emergência). Essa camada opera mesmo sem conexão de rede e sem consumir APIs externas, prevenindo a transmissão desnecessária de telemetria e assegurando alta disponibilidade operacional.

### Etapa 10: Acessibilidade Inclusiva e Segurança Visual Reativa
A segurança de software também contempla a precisão da informação transmitida visualmente ao usuário, prevenindo erros de tomada de decisão financeira causados por deficiências perceptivas:
* **Filtros Cromáticos Matriciais para Daltonismo (`AppSettingsController`):** O sistema implementa matrizes matemáticas de transformação espectral 4x5 (20 coeficientes de precisão) para conversão cromática em tempo real via `ColorFiltered` cobrindo Protanopia (espectro vermelho), Deuteranopia (espectro verde) e Tritanopia (espectro azul). Isso assegura que balanços, gráficos e cores de despesas/receitas sejam distinguidos com exatidão por usuários daltônicos.
* **Controle Reativo de Aparência e Escalonamento Tipográfico:** O suporte a Modo Escuro de alto contraste e a escala dinâmica de fontes garantem usabilidade confortável e segura para usuários com baixa acuidade visual.

### Etapa 11: Privacidade, Minimização e Direito ao Esquecimento (Conformidade com a LGPD)
O COGITO foi arquitetado em total conformidade com a Lei Geral de Proteção de Dados (Lei Federal nº 13.709/2018):
* **Princípio da Minimização de Dados (Art. 6º, III):** O sistema coleta estritamente os dados pertinentes para a finalidade orçamentária (nome, e-mail, telefone de contato, faixa etária e perfil de renda), dispensando a captura desnecessária de documentos civis sensíveis como CPF ou dados biométricos em servidores.
* **Direito à Eliminação Definitiva dos Dados (Art. 18, VI e Art. 16):** A aplicação implementa o método `apagarTodosDadosDoUsuario`, que realiza o expurgo completo e irreversível de todos os registros distribuídos em 8 coleções distintas do Cloud Firestore (`transacoes`, `conrado_chats`, `metas_financeiras`, `orcamentos`, `notificacoes`, `contas_bancarias`, `cartoes` e `usuarios`), seguido pela exclusão da conta no Firebase Auth.

### Etapa 12: DevSecOps, Auditoria Contínua de Segredos e Quality Gate no CI/CD
A segurança do COGITO é validada de forma contínua e automatizada na esteira de engenharia de software via GitHub Actions:
* **Auditoria de Vazamento de Segredos com Gitleaks:** A cada *push* ou *pull request*, o workflow do GitHub Actions executa uma varredura automatizada com o **Gitleaks**, impedindo que credenciais, chaves de API do Gemini ou certificados privados sejam comitados no código-fonte.
* **Quality Gate Obrigatório:** O pipeline executa auditoria estática com regras severas do linter (`flutter analyze`), verificação de formatação (`dart format`) e uma suíte completa de testes unitários com medição de cobertura (`flutter test --coverage`). Falhas no Quality Gate bloqueiam automaticamente a mesclagem de código.
* **Integridade Criptográfica de Distribuição (CD):** A esteira de distribuição compila os artefatos oficiais de produção (APK e Android App Bundle - AAB), calcula a impressão digital criptográfica via **SHA-256** e assina digitalmente os binários com chaves protegidas nos segredos criptografados do GitHub (*GitHub Secrets*).

---

## 3. POR QUE A SEGURANÇA DE DADOS É FUNDAMENTAL NESTA PLATAFORMA

A implementação rigorosa das diretrizes acima consolida a viabilidade operacional, ética, legal e estratégica do aplicativo COGITO no mercado financeiro e tecnológico:

* **Conformidade Estrita com a Lei Geral de Proteção de Dados (LGPD - Lei nº 13.709/2018):** Dados financeiros pessoais gozam de proteção jurídica privilegiada, pois revelam o estilo de vida, poder aquisitivo e rotina do cidadão. O descumprimento legal sujeitaria os mantenedores da plataforma a penalidades administrativas que chegam a multas vultosas, além de ações judiciais de reparação moral e patrimonial. O COGITO assegura transparência, segurança, prevenção e o exercício inalienável dos direitos dos titulares.
* **Construção de Confiança do Usuário em Serviços Financeiros Pessoais:** O engajamento com um gestor financeiro depende intrinsecamente da credibilidade do aplicativo. Ninguém confia seus lançamentos bancários, renda mensal e planos de poupança a um ecossistema suscetível a vazamentos, bisbilhotagem ou sequestro de dados.
* **Mitigação de Fraudes e Manipulação Contábil:** A validação estrita de tipos, isolamento de propriedade por identificador único e autenticação biométrica em hardware impedem que terceiros acessem ou corrompam balanços orçamentários, protejam o histórico de metas e garantam que a consultoria do CONRADO atenda privativamente a cada titular.
* **Resiliência e Continuidade dos Serviços:** A blindagem arquitetural contra injeções, o expurgo de dependências de arquivos de upload arbitrário no servidor e o mecanismo de contingência local do assistente CONRADO asseguram que o aplicativo funcione com estabilidade, garantindo alta disponibilidade mesmo diante de instabilidades parciais na nuvem.

---

## 4. DIRETRIZES TÉCNICAS RECOMENDADAS PARA AMBIENTE DE PRODUÇÃO

Para manter e expandir o patamar de segurança estabelecido no código-fonte em ambientes de produção e distribuição pública nas lojas de aplicativos (Google Play Store e Apple App Store), recomendam-se as seguintes configurações operacionais:

* **Comunicação Criptografada HTTPS e Certificate Pinning:** Todas as chamadas de rede com a API do Google Gemini e serviços Firebase devem trafegar exclusivamente sob protocolo HTTPS com TLS 1.3. Recomenda-se a ativação de *SSL/TLS Certificate Pinning* em versões de produção do aplicativo, evitando ataques do tipo *Man-in-the-Middle* (MitM) em redes Wi-Fi públicas.
* **Regras Estritas de Segurança no Cloud Firestore (*Firestore Security Rules*):** Publicação e auditoria contínua de regras declarativas no Firebase Console que validem a autenticidade e a propriedade dos dados na camada de nuvem:
  ```javascript
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /{collectionName}/{docId} {
        allow read, write: if request.auth != null && 
          (resource == null || resource.data.id_cliente == request.auth.uid || docId == request.auth.uid);
      }
    }
  }
  ```
* **Proteção contra Violação de Integridade com Firebase App Check:** Implementação do *Firebase App Check* com atestação de integridade nativa do dispositivo (Play Integrity no Android e DeviceCheck/App Attest no iOS), bloqueando requisições provenientes de aplicativos modificados, clonados ou emuladores não autorizados.
* **Ofuscação de Binários e Minificação de Código (R8/ProGuard):** Ativação dos recursos `--obfuscate` e `--split-debug-info` no comando de compilação do Flutter para a geração do APK/AAB de produção. Isso transforma identificadores e estruturas de classes em caracteres opacos, dificultando expressivamente a engenharia reversa por agentes mal-intencionados.
* **Gestão Centralizada de Chaves com Secret Manager:** Assegurar que as chaves de API da Gemini IA permaneçam segregadas em cofres de segredos gerenciados e protegidas por restrições de chamadas de pacote (*Package Name & SHA-1 fingerprint restriction*) no Google Cloud Console.
* **Rotinas Automatizadas de Backup e Recuperação de Desastres:** Habilitação de backups agendados periódicos das coleções do Cloud Firestore para buckets seguros no Google Cloud Storage (GCS), com retenção configurada e plano testado de restauração contínua de dados.

---

## 5. CONCLUSÃO

A análise da arquitetura e do código-fonte do aplicativo **COGITO** comprova que a segurança da informação e a privacidade foram integradas de maneira orgânica em todas as camadas e fases da solução. Desde a captura higienizada de dados nos formulários e autenticação biométrica nativa no hardware, passando pelo isolamento multi-tenant de documentos no Cloud Firestore e as salvaguardas éticas do assistente inteligente CONRADO, até a esteira de integração e entrega contínua (CI/CD) equipada com análise estática de vulnerabilidades e Gitleaks, o sistema reflete o estado da arte do desenvolvimento seguro.

Dessa forma, o COGITO estabelece um ambiente confiável, robusto e em estrita conformidade com as diretrizes da Lei Geral de Proteção de Dados (LGPD) e com as melhores práticas mundiais de segurança da informação (OWASP Mobile Security), salvaguardando a privacidade e a estabilidade financeira de seus usuários e garantindo a sustentabilidade e a reputação do projeto.
