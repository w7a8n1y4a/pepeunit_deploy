import os
import base64
import logging
import enum

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

class PathEnvs(enum.Enum):
    LOCAL_ENV = '.env.local'
    GLOBAL_ENV = '.env.global'
    
    EMQX = 'env/.env.emqx'
    POSTGRES = 'env/.env.postgres'
    BACKEND = 'env/.env.backend'
    FRONTEND = 'env/.env.frontend'

class MakeEnv:
    target_user_env: str
    is_user_local_env: bool
    
    current_user_env: dict = {}
    
    def __init__(self):
        
        logging.info('Run make envs')
        logging.info('Run search .env.local or .env.global')
        if os.path.exists(PathEnvs.LOCAL_ENV.value):
            logging.info('The .env.local file was found')
            self.target_user_env = PathEnvs.LOCAL_ENV.value
            self.is_user_local_env = True
        elif os.path.exists(PathEnvs.GLOBAL_ENV.value):   
            logging.info('The .env.global file was found')
            self.target_user_env = PathEnvs.GLOBAL_ENV.value
            self.is_user_local_env = False
        else:
            logging.error('No sample env files were found. Create an .env.local or .env.global file')
            
        self.current_user_env = self.load_env(self.target_user_env)
        
        self.save_env(self.get_emqx_env_dict(), PathEnvs.EMQX.value)
        self.save_env(self.get_postgres_env_dict(), PathEnvs.POSTGRES.value)
        self.save_env(self.get_frontend_env_dict(), PathEnvs.FRONTEND.value)
        self.save_env(self.get_backend_env_dict(), PathEnvs.BACKEND.value)
        
        logging.info('Environment file generation is complete')
    
    def get_emqx_env_dict(self) -> dict:
        logging.info('Generate .env.emqx')
        return {
            'EMQX_DASHBOARD__DEFAULT_USERNAME': self.current_user_env['MQTT_USERNAME'],
            'EMQX_DASHBOARD__DEFAULT_PASSWORD': self.current_user_env['MQTT_PASSWORD'],
        }
        
    def get_postgres_env_dict(self) -> dict:
        logging.info('Generate .env.postgres')
        return {
            'POSTGRES_USER': self.current_user_env['POSTGRES_USER'],
            'POSTGRES_PASSWORD': self.current_user_env['POSTGRES_PASSWORD'],
            'POSTGRES_DB': self.current_user_env['POSTGRES_DB'],
            'POSTGRES_HOST_AUTH_METHOD': 'md5'
        }
        
    def get_frontend_env_dict(self) -> dict:
        logging.info('Generate .env.frontend')
        domain = self.current_user_env['BACKEND_DOMAIN']
        https = 'http://' if 'SECURE' in self.current_user_env and self.current_user_env['SECURE'] == 'False' else 'https://'
        url = https + domain + '/'
        
        return {
            'VITE_INSTANCE_NAME': domain,
            'VITE_SELF_URI': url,
            'VITE_BACKEND_URI': url + 'pepeunit/graphql'
        }
        
    def get_backend_env_dict(self) -> dict:
        logging.info('Generate .env.backend')
        
        postgres_user: str = self.current_user_env['POSTGRES_USER']
        postgres_pass: str = self.current_user_env['POSTGRES_PASSWORD']
        postgres_db: str = self.current_user_env['POSTGRES_DB']
        database_url: str = f'postgresql://{postgres_user}:{postgres_pass}@postgres:5432/{postgres_db}'
        
        result_dict = {
            'BACKEND_DOMAIN': self.current_user_env['BACKEND_DOMAIN'],
            'SQLALCHEMY_DATABASE_URL': database_url,
            'SECRET_KEY': base64.b64encode(os.urandom(32)).decode('utf-8'),
            'ENCRYPT_KEY': base64.b64encode(os.urandom(32)).decode('utf-8'),
            'STATIC_SALT': base64.b64encode(os.urandom(32)).decode('utf-8'),
            'TELEGRAM_TOKEN': self.current_user_env['TELEGRAM_TOKEN'],
            'TELEGRAM_BOT_LINK': self.current_user_env['TELEGRAM_BOT_LINK'],
            'MQTT_HOST': self.current_user_env['MQTT_HOST'],
            'MQTT_USERNAME': self.current_user_env['MQTT_USERNAME'],
            'MQTT_PASSWORD': self.current_user_env['MQTT_PASSWORD']
        }
        
        if 'SECURE' in self.current_user_env:
            result_dict['SECURE'] = self.current_user_env['SECURE']
            
        if 'MQTT_SECURE' in self.current_user_env:
            result_dict['MQTT_SECURE'] = self.current_user_env['MQTT_SECURE']
            
        return result_dict
    
    def load_env(self, filename: str) -> dict:
        logging.info(f'Load variables from {filename}')
        
        env_dict = {}
        with open(filename, "r") as file:
            for line in file:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    env_dict[key.strip()] = value.strip()
                    
        return env_dict
    
    def save_env(self, env_dict: dict, filename: str) -> None:
        logging.info(f'Save {filename}')
        
        with open(filename, "w") as file:
            for key, value in env_dict.items():
                file.write(f"{key}={value}\n")

    
    
if __name__ == '__main__':
    env_maker = MakeEnv()