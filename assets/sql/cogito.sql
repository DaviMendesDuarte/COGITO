CREATE DATABASE IF NOT EXISTS cogito;
USE cogito;

CREATE TABLE IF NOT EXISTS clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefone VARCHAR(20),
    idade TINYINT UNSIGNED,
    senha_hash VARCHAR(255) NOT NULL,
    tipo_renda ENUM('Salario_Fixo', 'Freelancer') NOT NULL,
    renda_mensal DECIMAL(10,2),
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    ultimo_acesso DATETIME,
    status_conta ENUM('Ativa', 'Suspensa', 'Inativa') DEFAULT 'Ativa',
    foto_perfil VARCHAR(255),
    consentimento_lgpd BOOLEAN DEFAULT FALSE,
    notificacoes_ativas BOOLEAN DEFAULT TRUE,
    meta_economia DECIMAL(10,2) DEFAULT 0.00,
    limite_gastos_mensal DECIMAL(10,2) DEFAULT 0.00
);

DELIMITER $$

CREATE PROCEDURE criar_usuario(
    IN p_nome VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_telefone VARCHAR(20),
    IN p_idade TINYINT UNSIGNED,
    IN p_senha_hash VARCHAR(255),
    IN p_tipo_renda ENUM('Salario_Fixo','Freelancer'),
    IN p_renda_mensal DECIMAL(10,2)
)
BEGIN
    INSERT INTO clientes(nome, email, telefone, idade, senha_hash, tipo_renda, renda_mensal)
    VALUES(p_nome, p_email, p_telefone, p_idade, p_senha_hash, p_tipo_renda, p_renda_mensal);
END$$

CREATE FUNCTION login_usuario(p_email VARCHAR(100), p_senha_hash VARCHAR(255))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_id INT;
    SELECT id_cliente INTO v_id
    FROM clientes
    WHERE email = p_email AND senha_hash = p_senha_hash
    LIMIT 1;
    RETURN v_id;
END$$

CREATE PROCEDURE buscar_usuario(IN p_id INT)
BEGIN
    SELECT * FROM clientes WHERE id_cliente = p_id;
END$$

CREATE PROCEDURE atualizar_usuario(
    IN p_id INT,
    IN p_nome VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_telefone VARCHAR(20),
    IN p_idade TINYINT UNSIGNED,
    IN p_tipo_renda ENUM('Salario_Fixo','Freelancer'),
    IN p_renda_mensal DECIMAL(10,2),
    IN p_meta_economia DECIMAL(10,2),
    IN p_limite_gastos_mensal DECIMAL(10,2)
)
BEGIN
    UPDATE clientes
    SET nome = p_nome,
        email = p_email,
        telefone = p_telefone,
        idade = p_idade,
        tipo_renda = p_tipo_renda,
        renda_mensal = p_renda_mensal,
        meta_economia = p_meta_economia,
        limite_gastos_mensal = p_limite_gastos_mensal
    WHERE id_cliente = p_id;
END$$

CREATE PROCEDURE excluir_usuario(IN p_id INT)
BEGIN
    UPDATE clientes
    SET status_conta = 'Inativa'
    WHERE id_cliente = p_id;
END$$

DELIMITER ;