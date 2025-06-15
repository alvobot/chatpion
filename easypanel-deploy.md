# ChatPion - Guia de Implantação no EasyPanel

## Opção 1: Usando o Script de Deploy (RECOMENDADO)

### 1. No EasyPanel, crie um novo serviço:
- **Tipo**: App
- **Nome**: chatpion
- **Imagem**: Deixe vazio (vamos usar GitHub)

### 2. Configure a fonte:
- **Source**: GitHub
- **Repository**: https://github.com/alvobot/chatpion
- **Branch**: main (ou master)

### 3. Variáveis de Ambiente:
```env
DB_HOST=mysql
DB_USER=chatpion
DB_PASS=SuaSenhaSegura123
DB_NAME=chatpion_db
APP_URL=https://seu-dominio.com
```

### 4. Configure o Build:
- **Dockerfile Path**: /Dockerfile
- **Build Context**: /

### 5. Configurações do Container:
- **Port**: 80
- **Health Check Path**: /

### 6. Volumes Persistentes:
Adicione os seguintes volumes:
- `/var/www/html/upload` → Volume: chatpion-upload
- `/var/www/html/upload_caster` → Volume: chatpion-caster
- `/var/www/html/download` → Volume: chatpion-download

### 7. Banco de Dados MySQL:
Crie um serviço MySQL separado:
- **Nome**: mysql
- **Imagem**: mysql:5.7
- **Variáveis**:
  ```env
  MYSQL_ROOT_PASSWORD=RootPassword123
  MYSQL_DATABASE=chatpion_db
  MYSQL_USER=chatpion
  MYSQL_PASSWORD=SuaSenhaSegura123
  ```
- **Volume**: `/var/lib/mysql` → mysql-data

---

## Opção 2: Deploy Manual (Alternativa)

### 1. Clone o repositório localmente:
```bash
git clone https://github.com/alvobot/chatpion
cd chatpion
```

### 2. Copie os arquivos criados:
- `deploy.sh`
- `Dockerfile`
- `docker-compose.yml`

### 3. Faça push para seu próprio repositório

### 4. Use seu repositório no EasyPanel

---

## Configuração Pós-Deploy

### 1. Acesse o container via terminal:
```bash
docker exec -it chatpion-app bash
```

### 2. Execute o script de deploy:
```bash
/usr/local/bin/deploy.sh
```

### 3. Verifique os logs:
```bash
tail -f /var/log/apache2/error.log
```

### 4. Primeiro Acesso:
- URL: `https://seu-dominio.com`
- Email: `admin@chatpion.com`
- Senha: (será mostrada no log do deploy.sh)

---

## Configurações Importantes

### SSL/HTTPS:
No EasyPanel, ative o SSL:
- Domains → Add Domain
- Enable SSL
- Force HTTPS

### Cron Jobs:
O Dockerfile já configura os cron jobs automaticamente.

### Backups:
Configure backups dos volumes:
- chatpion-upload
- chatpion-caster
- chatpion-download
- mysql-data

### Performance:
Para sites com alto tráfego, ajuste:
- Resources → Memory: 2GB+
- Resources → CPU: 2+ cores

---

## Solução de Problemas

### Erro de Permissão:
```bash
docker exec -it chatpion-app bash
chmod -R 777 /var/www/html/upload
chmod -R 777 /var/www/html/application/cache
```

### Erro de Banco de Dados:
```bash
# Verificar conexão
docker exec -it chatpion-app bash
mysql -h mysql -u chatpion -p
```

### Logs de Erro:
```bash
# Apache logs
docker logs chatpion-app

# PHP logs
docker exec -it chatpion-app tail -f /var/log/apache2/error.log
```

---

## Checklist Final

- [ ] Deploy concluído sem erros
- [ ] Site acessível via HTTPS
- [ ] Login admin funcionando
- [ ] Trocar senha padrão do admin
- [ ] Configurar SMTP para emails
- [ ] Configurar Facebook App
- [ ] Configurar gateways de pagamento
- [ ] Testar upload de arquivos
- [ ] Verificar cron jobs rodando

---

## Suporte

Para problemas específicos do ChatPion:
- Documentação: `/documentation/`
- Logs: `/var/log/chatpion/`
- Cache: Limpar em `/application/cache/`