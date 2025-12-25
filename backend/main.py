from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional
from datetime import datetime, timedelta
from jose import JWTError, jwt
import sqlite3
import secrets

# ===========================================
# CONFIGURATION
# ===========================================

SECRET_KEY = secrets.token_urlsafe(32)  # Génère une clé sécurisée aléatoire
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Base de données
DATABASE_URL = "contacts.db"

# Initialiser FastAPI
app = FastAPI(
    title="Contacts API",
    version="1.0.0",
    description="API de gestion de contacts avec authentification JWT",
    docs_url="/docs",
    redoc_url="/redoc"
)

# ===========================================
# CORS MIDDLEWARE - CORRIGÉ
# ===========================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Autorise TOUT
    allow_credentials=True,
    allow_methods=["*"],  # Autorise TOUTES les méthodes
    allow_headers=["*"],  # Autorise TOUS les headers
)

# ===========================================
# MODÈLES PYDANTIC
# ===========================================

class UserBase(BaseModel):
    first_name: str = Field(..., min_length=1, max_length=50, example="Jean")
    last_name: str = Field(..., min_length=1, max_length=50, example="Dupont")
    email: EmailStr = Field(..., example="jean.dupont@example.com")

class UserCreate(UserBase):
    password: str = Field(..., min_length=6, max_length=100, example="password123")

class UserResponse(UserBase):
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

class UserLogin(BaseModel):
    email: EmailStr = Field(..., example="jean.dupont@example.com")
    password: str = Field(..., example="password123")

class ContactBase(BaseModel):
    first_name: str = Field(..., min_length=1, max_length=50, example="Marie")
    last_name: str = Field(..., min_length=1, max_length=50, example="Curie")
    phone: str = Field(..., min_length=10, max_length=20, example="0123456789")
    email: Optional[EmailStr] = Field(None, example="marie.curie@example.com")

class ContactResponse(ContactBase):
    id: int
    user_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

class TokenData(BaseModel):
    email: Optional[str] = None
    user_id: Optional[int] = None

# ===========================================
# OAuth2 SCHEME
# ===========================================

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# ===========================================
# FONCTIONS UTILITAIRES
# ===========================================

def get_password_hash(password: str) -> str:
    """Version SIMPLE : pas de hash pour faciliter les tests"""
    print(f"📝 Mot de passe stocké : {password}")
    return password

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Version SIMPLE : compare directement"""
    print(f"🔐 Comparaison : '{plain_password}' == '{hashed_password}'")
    return plain_password == hashed_password

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_db_connection():
    conn = sqlite3.connect(DATABASE_URL)
    conn.row_factory = sqlite3.Row
    return conn

# ===========================================
# INITIALISATION DE LA BASE DE DONNÉES
# ===========================================

def init_db():
    conn = sqlite3.connect(DATABASE_URL)
    cursor = conn.cursor()
    
    # Table des utilisateurs
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Table des contacts
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
    ''')
    
    # Créer un index pour accélérer les recherches
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_contacts_user_id 
        ON contacts(user_id)
    ''')
    
    # Créer un utilisateur de test s'il n'existe pas
    cursor.execute("SELECT COUNT(*) FROM users WHERE email = 'test@test.com'")
    if cursor.fetchone()[0] == 0:
        cursor.execute(
            "INSERT INTO users (first_name, last_name, email, password) VALUES (?, ?, ?, ?)",
            ("Test", "User", "test@test.com", "test123")
        )
        print("✅ Utilisateur de test créé: test@test.com / test123")
    
    conn.commit()
    conn.close()
    print("✅ Base de données initialisée !")

# Appeler init_db au démarrage
init_db()

# ===========================================
# AUTHENTIFICATION
# ===========================================

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Impossible de valider les identifiants",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        user_id: int = payload.get("user_id")
        if email is None or user_id is None:
            raise credentials_exception
        token_data = TokenData(email=email, user_id=user_id)
    except JWTError:
        raise credentials_exception
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, first_name, last_name, email, created_at FROM users WHERE id = ? AND email = ?",
        (token_data.user_id, token_data.email)
    )
    user = cursor.fetchone()
    conn.close()
    
    if user is None:
        raise credentials_exception
    return dict(user)

async def get_current_active_user(current_user: dict = Depends(get_current_user)):
    return current_user

# ===========================================
# ROUTES
# ===========================================

@app.get("/")
def read_root():
    return {
        "message": "Bienvenue sur l'API Contacts",
        "version": "1.0.0",
        "documentation": "/docs",
        "endpoints": {
            "auth": ["/register", "/token", "/me"],
            "contacts": ["/contacts (GET, POST)", "/contacts/{id} (GET, PUT, DELETE)"],
            "search": ["/contacts/search/{query}"],
            "test": ["/health", "/test-db"]
        }
    }

@app.get("/health")
def health_check():
    """Vérifie l'état de l'API"""
    try:
        conn = get_db_connection()
        conn.close()
        db_status = "healthy"
    except:
        db_status = "unhealthy"
    
    return {
        "status": "ok",
        "database": db_status,
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/test-db")
def test_db():
    """Teste la connexion à la base de données"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Compter les utilisateurs
        cursor.execute("SELECT COUNT(*) FROM users")
        user_count = cursor.fetchone()[0]
        
        # Compter les contacts
        cursor.execute("SELECT COUNT(*) FROM contacts")
        contact_count = cursor.fetchone()[0]
        
        # Lister les utilisateurs
        cursor.execute("SELECT id, email FROM users")
        users = cursor.fetchall()
        
        conn.close()
        
        return {
            "status": "OK",
            "database": DATABASE_URL,
            "users_count": user_count,
            "contacts_count": contact_count,
            "users": [dict(u) for u in users]
        }
    except Exception as e:
        return {"status": "ERROR", "error": str(e)}

# ===========================================
# AUTHENTIFICATION - ROUTES
# ===========================================

@app.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user: UserCreate):
    """Inscription d'un nouvel utilisateur"""
    print(f"📝 Tentative d'inscription pour: {user.email}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Vérifier si l'email existe déjà
    cursor.execute("SELECT id FROM users WHERE email = ?", (user.email,))
    if cursor.fetchone():
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cet email est déjà utilisé"
        )
    
    # Hasher le mot de passe
    hashed_password = get_password_hash(user.password)
    
    # Insérer l'utilisateur
    try:
        cursor.execute(
            "INSERT INTO users (first_name, last_name, email, password) VALUES (?, ?, ?, ?)",
            (user.first_name, user.last_name, user.email, hashed_password)
        )
        conn.commit()
        user_id = cursor.lastrowid
        
        # Récupérer l'utilisateur créé
        cursor.execute(
            "SELECT id, first_name, last_name, email, created_at FROM users WHERE id = ?",
            (user_id,)
        )
        new_user = cursor.fetchone()
        conn.close()
        
        print(f"✅ Utilisateur créé avec ID: {user_id}")
        return dict(new_user)
    except Exception as e:
        conn.close()
        print(f"❌ Erreur lors de l'inscription: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur lors de l'inscription: {str(e)}"
        )

@app.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """Connexion et obtention du token JWT"""
    print(f"🔑 Tentative de connexion pour: {form_data.username}")
    print(f"🔑 Mot de passe reçu: {form_data.password}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Récupérer l'utilisateur
    cursor.execute(
        "SELECT id, first_name, last_name, email, password, created_at FROM users WHERE email = ?",
        (form_data.username,)
    )
    user = cursor.fetchone()
    conn.close()
    
    if not user:
        print(f"❌ Utilisateur non trouvé: {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    print(f"✅ Utilisateur trouvé: {user['email']}")
    print(f"🔐 Vérification du mot de passe...")
    
    # Vérifier le mot de passe
    if not verify_password(form_data.password, user["password"]):
        print(f"❌ Mot de passe incorrect")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    print(f"✅ Mot de passe correct")
    
    # Créer le token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["email"], "user_id": user["id"]}, 
        expires_delta=access_token_expires
    )
    
    user_response = {
        "id": user["id"],
        "first_name": user["first_name"],
        "last_name": user["last_name"],
        "email": user["email"],
        "created_at": user["created_at"]
    }
    
    print(f"✅ Connexion réussie pour: {user['email']}")
    print(f"🔑 Token généré: {access_token[:20]}...")
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user_response
    }

@app.get("/me", response_model=UserResponse)
def get_me(current_user: dict = Depends(get_current_active_user)):
    """Obtenir les informations de l'utilisateur connecté"""
    return current_user

# ===========================================
# CONTACTS - ROUTES
# ===========================================

@app.get("/contacts", response_model=List[ContactResponse])
def get_contacts(
    skip: int = 0,
    limit: int = 100,
    current_user: dict = Depends(get_current_active_user)
):
    """Récupérer tous les contacts de l'utilisateur"""
    print(f"📋 Récupération des contacts pour user_id: {current_user['id']}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        """SELECT id, user_id, first_name, last_name, phone, email, created_at 
           FROM contacts WHERE user_id = ? 
           ORDER BY created_at DESC 
           LIMIT ? OFFSET ?""",
        (current_user["id"], limit, skip)
    )
    contacts = cursor.fetchall()
    conn.close()
    
    print(f"✅ {len(contacts)} contacts récupérés")
    return [dict(contact) for contact in contacts]

@app.post("/contacts", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
def create_contact(
    contact: ContactBase,
    current_user: dict = Depends(get_current_active_user)
):
    """Créer un nouveau contact"""
    print(f"➕ Création d'un contact pour user_id: {current_user['id']}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            """INSERT INTO contacts 
               (user_id, first_name, last_name, phone, email) 
               VALUES (?, ?, ?, ?, ?)""",
            (current_user["id"], contact.first_name, contact.last_name, contact.phone, contact.email)
        )
        conn.commit()
        contact_id = cursor.lastrowid
        
        cursor.execute(
            """SELECT id, user_id, first_name, last_name, phone, email, created_at 
               FROM contacts WHERE id = ?""",
            (contact_id,)
        )
        new_contact = cursor.fetchone()
        conn.close()
        
        print(f"✅ Contact créé avec ID: {contact_id}")
        return dict(new_contact)
    except Exception as e:
        conn.close()
        print(f"❌ Erreur création contact: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur lors de la création du contact: {str(e)}"
        )

@app.get("/contacts/{contact_id}", response_model=ContactResponse)
def get_contact(
    contact_id: int,
    current_user: dict = Depends(get_current_active_user)
):
    """Récupérer un contact spécifique"""
    print(f"🔍 Récupération du contact {contact_id} pour user_id: {current_user['id']}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        """SELECT id, user_id, first_name, last_name, phone, email, created_at 
           FROM contacts WHERE id = ? AND user_id = ?""",
        (contact_id, current_user["id"])
    )
    contact = cursor.fetchone()
    conn.close()
    
    if contact is None:
        print(f"❌ Contact {contact_id} non trouvé")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact non trouvé"
        )
    
    print(f"✅ Contact {contact_id} trouvé")
    return dict(contact)

@app.put("/contacts/{contact_id}", response_model=ContactResponse)
def update_contact(
    contact_id: int,
    contact: ContactBase,
    current_user: dict = Depends(get_current_active_user)
):
    """Mettre à jour un contact"""
    print(f"✏️ Mise à jour du contact {contact_id} pour user_id: {current_user['id']}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Vérifier que le contact appartient à l'utilisateur
    cursor.execute(
        "SELECT id FROM contacts WHERE id = ? AND user_id = ?", 
        (contact_id, current_user["id"])
    )
    if not cursor.fetchone():
        conn.close()
        print(f"❌ Contact {contact_id} non trouvé pour user_id: {current_user['id']}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact non trouvé"
        )
    
    # Mettre à jour
    try:
        cursor.execute(
            """UPDATE contacts 
               SET first_name = ?, last_name = ?, phone = ?, email = ? 
               WHERE id = ?""",
            (contact.first_name, contact.last_name, contact.phone, contact.email, contact_id)
        )
        conn.commit()
        
        cursor.execute(
            "SELECT * FROM contacts WHERE id = ?", 
            (contact_id,)
        )
        updated_contact = cursor.fetchone()
        conn.close()
        
        print(f"✅ Contact {contact_id} mis à jour")
        return dict(updated_contact)
    except Exception as e:
        conn.close()
        print(f"❌ Erreur mise à jour contact: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur lors de la mise à jour: {str(e)}"
        )

@app.delete("/contacts/{contact_id}", status_code=status.HTTP_200_OK)
def delete_contact(
    contact_id: int,
    current_user: dict = Depends(get_current_active_user)
):
    """Supprimer un contact"""
    print(f"🗑️ Suppression du contact {contact_id} pour user_id: {current_user['id']}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Vérifier que le contact appartient à l'utilisateur
    cursor.execute(
        "SELECT id FROM contacts WHERE id = ? AND user_id = ?", 
        (contact_id, current_user["id"])
    )
    if not cursor.fetchone():
        conn.close()
        print(f"❌ Contact {contact_id} non trouvé pour user_id: {current_user['id']}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact non trouvé"
        )
    
    # Supprimer
    try:
        cursor.execute("DELETE FROM contacts WHERE id = ?", (contact_id,))
        conn.commit()
        conn.close()
        
        print(f"✅ Contact {contact_id} supprimé")
        return {"message": "Contact supprimé avec succès"}
    except Exception as e:
        conn.close()
        print(f"❌ Erreur suppression contact: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur lors de la suppression: {str(e)}"
        )

@app.get("/contacts/search/{query}", response_model=List[ContactResponse])
def search_contacts(
    query: str,
    current_user: dict = Depends(get_current_active_user)
):
    """Rechercher des contacts"""
    if len(query) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La requête doit contenir au moins 2 caractères"
        )
    
    print(f"🔍 Recherche '{query}' pour user_id: {current_user['id']}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    search_pattern = f"%{query}%"
    cursor.execute(
        """SELECT id, user_id, first_name, last_name, phone, email, created_at 
           FROM contacts 
           WHERE user_id = ? 
           AND (first_name LIKE ? OR last_name LIKE ? OR phone LIKE ? OR email LIKE ?) 
           ORDER BY last_name, first_name""",
        (current_user["id"], search_pattern, search_pattern, search_pattern, search_pattern)
    )
    contacts = cursor.fetchall()
    conn.close()
    
    print(f"✅ {len(contacts)} contacts trouvés pour la recherche '{query}'")
    return [dict(contact) for contact in contacts]

# ===========================================
# ROUTE OPTIONS POUR CORS
# ===========================================

@app.options("/{full_path:path}")
async def options_handler():
    """Gère les requêtes OPTIONS pour CORS"""
    return {}

# ===========================================
# LANCEMENT DU SERVEUR
# ===========================================

if __name__ == "__main__":
    import uvicorn
    
    print("=" * 50)
    print("🚀 SERVEUR FASTAPI - CONTACTS MANAGEMENT")
    print("=" * 50)
    print("✅ Base de données initialisée")
    print("👤 Utilisateur de test: test@test.com / test123")
    print("🌐 URL: http://127.0.0.1:8000")
    print("📚 Documentation: http://127.0.0.1:8000/docs")
    print("🔍 Test API: http://127.0.0.1:8000/health")
    print("=" * 50)
    print("✅ Le serveur démarre maintenant...")
    print("=" * 50)
    
    # Version SIMPLE qui MARCHE TOUJOURS
    uvicorn.run(app, host="127.0.0.1", port=8000, reload=False)