"""
EmoTune BERT Emotion Classifier Training Script
================================================
Dataset: GoEmotions (Google) + Custom EmoTune dataset
Model: bert-base-uncased fine-tuned for 13 emotion categories
Emotions: happy, sad, angry, motivational, fear, depressing,
          surprising, stressed, calm, lonely, romantic, nostalgic, mixed
"""

import os
import json
import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import torch
from torch.utils.data import Dataset, DataLoader
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer,
    EarlyStoppingCallback,
)
from datasets import load_dataset
import warnings
warnings.filterwarnings('ignore')

# ============== CONFIGURATION ==============
MODEL_NAME = "bert-base-uncased"
OUTPUT_DIR = Path("ml/models/bert_emotion_model")
NUM_LABELS = 13
MAX_LENGTH = 128
BATCH_SIZE = 16
NUM_EPOCHS = 5
LEARNING_RATE = 2e-5
WARMUP_RATIO = 0.1

LABEL2ID = {
    'happy': 0, 'sad': 1, 'angry': 2, 'motivational': 3,
    'fear': 4, 'depressing': 5, 'surprising': 6, 'stressed': 7,
    'calm': 8, 'lonely': 9, 'romantic': 10, 'nostalgic': 11, 'mixed': 12
}
ID2LABEL = {v: k for k, v in LABEL2ID.items()}

# GoEmotions → EmoTune mapping
GOEMOTIONS_MAP = {
    'admiration': 'happy', 'amusement': 'happy', 'excitement': 'happy',
    'joy': 'happy', 'love': 'romantic', 'optimism': 'motivational',
    'pride': 'motivational', 'relief': 'calm', 'gratitude': 'happy',
    'approval': 'happy', 'caring': 'romantic',
    'sadness': 'sad', 'grief': 'sad', 'disappointment': 'sad',
    'remorse': 'sad', 'embarrassment': 'sad',
    'anger': 'angry', 'annoyance': 'angry', 'disgust': 'angry',
    'disapproval': 'angry',
    'fear': 'fear', 'nervousness': 'fear',
    'confusion': 'mixed', 'realization': 'surprising',
    'surprise': 'surprising', 'curiosity': 'surprising',
    'desire': 'romantic',
    'neutral': 'calm',
    'boredom': 'mixed',
}


# ============== CUSTOM DATASET ==============
CUSTOM_DATASET = [
    # Happy
    ("I'm so happy today, everything is going great!", "happy"),
    ("Just got promoted at work! Best day ever!", "happy"),
    ("My team won the championship! I'm ecstatic!", "happy"),
    ("Got an A on my exam, feeling on top of the world!", "happy"),
    ("Birthday celebration with all my friends was amazing!", "happy"),
    ("My baby took their first steps today!", "happy"),
    ("Just finished my favorite book and the ending was perfect!", "happy"),
    
    # Sad
    ("I miss my grandmother so much. She passed away last year.", "sad"),
    ("My best friend is moving to another country. I feel lost.", "sad"),
    ("I cried watching that movie, it hit too close to home.", "sad"),
    ("Failed my exam after studying for weeks. So disappointed.", "sad"),
    ("Nobody remembered my birthday today.", "sad"),
    ("Looking at old photos makes me sad about how things changed.", "sad"),
    
    # Angry
    ("I can't believe they lied to me. I'm furious!", "angry"),
    ("This traffic is making me so mad. I'm going to be late again!", "angry"),
    ("My roommate keeps leaving dishes in the sink, I'm fed up!", "angry"),
    ("They canceled my favorite show. This is outrageous!", "angry"),
    ("Why do people keep interrupting me? I'm losing my patience.", "angry"),
    
    # Motivational
    ("I'm going to crush this workout today! Nothing can stop me!", "motivational"),
    ("Every failure is just a stepping stone to success.", "motivational"),
    ("Starting my business today. Excited for this new chapter!", "motivational"),
    ("Going to study all night and ace this presentation!", "motivational"),
    ("I believe in myself. I can achieve anything I set my mind to!", "motivational"),
    ("Training for a marathon. No pain no gain!", "motivational"),
    
    # Fear
    ("I have my first job interview tomorrow. I'm terrified.", "fear"),
    ("There's a strange noise outside. I'm scared to check.", "fear"),
    ("I have anxiety about flying but I have a trip next week.", "fear"),
    ("Presenting in front of 500 people next week. Petrified.", "fear"),
    ("I'm worried something bad might happen to my family.", "fear"),
    
    # Depressing
    ("I feel empty inside. Nothing brings me joy anymore.", "depressing"),
    ("What's the point of anything? I can't see the light.", "depressing"),
    ("I've been feeling numb for weeks. Everything feels grey.", "depressing"),
    ("I don't want to get out of bed. Life feels meaningless.", "depressing"),
    ("I feel like I'm just going through the motions every day.", "depressing"),
    ("The darkness inside me won't go away no matter what I do.", "depressing"),
    
    # Surprising
    ("I just found out I'm pregnant! Complete shock!", "surprising"),
    ("My long lost sibling just called me out of nowhere!", "surprising"),
    ("Won the lottery today. I still can't believe it!", "surprising"),
    ("My boss just gave me an unexpected bonus. What a surprise!", "surprising"),
    ("Ran into my childhood friend at the airport in another country!", "surprising"),
    
    # Stressed
    ("I have three deadlines tomorrow and I haven't started any of them.", "stressed"),
    ("My boss wants the report in an hour. I'm overwhelmed.", "stressed"),
    ("Balancing work, school, and family is burning me out.", "stressed"),
    ("I can't sleep because I'm thinking about everything I need to do.", "stressed"),
    ("Finals week is here and I feel like I'm drowning.", "stressed"),
    ("Too many responsibilities, not enough time. Completely overwhelmed.", "stressed"),
    
    # Calm
    ("Just finished meditating. Feeling so peaceful and centered.", "calm"),
    ("Sitting by the ocean and watching the sunset. Pure bliss.", "calm"),
    ("Everything is in order and I feel at peace with the world.", "calm"),
    ("Reading a good book with a cup of tea. Perfectly content.", "calm"),
    ("A quiet Sunday morning with no plans. This is what I needed.", "calm"),
    
    # Lonely
    ("I have 500 friends on social media but I feel completely alone.", "lonely"),
    ("Moved to a new city and don't know anyone here.", "lonely"),
    ("Everyone seems to have their own lives. Nobody checks on me.", "lonely"),
    ("Sitting at home alone on a Friday night. Missing connection.", "lonely"),
    ("Even in a crowd I feel isolated and invisible.", "lonely"),
    
    # Romantic
    ("I'm so in love. Every moment with them feels magical.", "romantic"),
    ("Got flowers from my partner unexpectedly. My heart is full.", "romantic"),
    ("Planning a surprise date for my anniversary. Love is beautiful.", "romantic"),
    ("The way they look at me makes me feel like the only person in the world.", "romantic"),
    ("First date tonight! I have butterflies!", "romantic"),
    
    # Nostalgic
    ("Heard that song from 2008 and suddenly I'm 16 again.", "nostalgic"),
    ("Found my old diary. Remembering who I used to be.", "nostalgic"),
    ("Drove past my childhood home today. So many memories.", "nostalgic"),
    ("Rewatching old cartoons from my childhood. Simpler times.", "nostalgic"),
    ("Old photos with friends I've lost touch with. Miss those days.", "nostalgic"),
    
    # Mixed
    ("I got the job offer but it means leaving my family behind.", "mixed"),
    ("Happy it's my birthday but also reflecting on time passing.", "mixed"),
    ("Graduated today! Proud but nervous about what comes next.", "mixed"),
    ("My relationship ended. Sad but also relieved somehow.", "mixed"),
    ("Moving to my dream city but terrified of starting over.", "mixed"),
]


def load_goemotions():
    """Load and process GoEmotions dataset"""
    print("Loading GoEmotions dataset...")
    try:
        dataset = load_dataset("go_emotions", "simplified")
        texts, labels = [], []
        
        goemotions_labels = dataset['train'].features['labels'].feature.names
        
        for item in dataset['train']:
            text = item['text']
            item_labels = item['labels']
            if not item_labels:
                continue
            
            # Get primary emotion
            primary_label = goemotions_labels[item_labels[0]]
            mapped = GOEMOTIONS_MAP.get(primary_label)
            if mapped:
                texts.append(text)
                labels.append(mapped)
        
        print(f"Loaded {len(texts)} samples from GoEmotions")
        return texts, labels
    except Exception as e:
        print(f"Could not load GoEmotions: {e}")
        return [], []


def prepare_dataset():
    """Combine GoEmotions with custom dataset"""
    texts, labels = load_goemotions()
    
    # Add custom dataset (repeated for balance)
    custom_texts = [item[0] for item in CUSTOM_DATASET]
    custom_labels = [item[1] for item in CUSTOM_DATASET]
    
    # Repeat custom data 10x for better representation
    texts.extend(custom_texts * 10)
    labels.extend(custom_labels * 10)
    
    # Convert to numeric
    numeric_labels = [LABEL2ID[l] for l in labels]
    
    # Balance dataset
    df = pd.DataFrame({'text': texts, 'label': numeric_labels})
    
    # Sample max 2000 per class
    balanced = []
    for label_id in range(NUM_LABELS):
        cls_df = df[df['label'] == label_id]
        if len(cls_df) > 2000:
            cls_df = cls_df.sample(2000, random_state=42)
        balanced.append(cls_df)
    
    df = pd.concat(balanced).sample(frac=1, random_state=42)
    
    print(f"\nDataset distribution:")
    for label_id, count in df['label'].value_counts().sort_index().items():
        print(f"  {ID2LABEL[label_id]}: {count}")
    
    return df['text'].tolist(), df['label'].tolist()


class EmotionDataset(Dataset):
    def __init__(self, texts, labels, tokenizer, max_length=MAX_LENGTH):
        self.encodings = tokenizer(
            texts,
            truncation=True,
            padding='max_length',
            max_length=max_length,
            return_tensors='pt'
        )
        self.labels = torch.tensor(labels, dtype=torch.long)

    def __len__(self):
        return len(self.labels)

    def __getitem__(self, idx):
        item = {k: v[idx] for k, v in self.encodings.items()}
        item['labels'] = self.labels[idx]
        return item


def compute_metrics(eval_pred):
    from sklearn.metrics import accuracy_score, f1_score
    logits, labels = eval_pred
    predictions = np.argmax(logits, axis=-1)
    accuracy = accuracy_score(labels, predictions)
    f1 = f1_score(labels, predictions, average='weighted')
    return {'accuracy': accuracy, 'f1': f1}


def train():
    print("=" * 60)
    print("EmoTune BERT Emotion Classifier Training")
    print("=" * 60)
    
    # Prepare data
    texts, labels = prepare_dataset()
    
    # Split
    X_train, X_val, y_train, y_val = train_test_split(
        texts, labels, test_size=0.15, random_state=42, stratify=labels
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_val, y_val, test_size=0.5, random_state=42
    )
    
    print(f"\nSplit: Train={len(X_train)}, Val={len(X_val)}, Test={len(X_test)}")
    
    # Load tokenizer and model
    print(f"\nLoading {MODEL_NAME}...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_NAME,
        num_labels=NUM_LABELS,
        id2label=ID2LABEL,
        label2id=LABEL2ID,
    )
    
    # Create datasets
    train_dataset = EmotionDataset(X_train, y_train, tokenizer)
    val_dataset = EmotionDataset(X_val, y_val, tokenizer)
    test_dataset = EmotionDataset(X_test, y_test, tokenizer)
    
    # Training args
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    training_args = TrainingArguments(
        output_dir=str(OUTPUT_DIR),
        num_train_epochs=NUM_EPOCHS,
        per_device_train_batch_size=BATCH_SIZE,
        per_device_eval_batch_size=BATCH_SIZE,
        learning_rate=LEARNING_RATE,
        warmup_ratio=WARMUP_RATIO,
        weight_decay=0.01,
        evaluation_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="f1",
        logging_dir=str(OUTPUT_DIR / "logs"),
        logging_steps=50,
        report_to="none",
        fp16=torch.cuda.is_available(),
    )
    
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=val_dataset,
        compute_metrics=compute_metrics,
        callbacks=[EarlyStoppingCallback(early_stopping_patience=2)],
    )
    
    # Train
    print("\nStarting training...")
    trainer.train()
    
    # Save model
    print("\nSaving model...")
    trainer.save_model(str(OUTPUT_DIR))
    tokenizer.save_pretrained(str(OUTPUT_DIR))
    
    # Evaluate on test set
    print("\n" + "=" * 40)
    print("TEST SET EVALUATION")
    print("=" * 40)
    predictions = trainer.predict(test_dataset)
    preds = np.argmax(predictions.predictions, axis=-1)
    
    print("\nClassification Report:")
    print(classification_report(
        y_test, preds,
        target_names=[ID2LABEL[i] for i in range(NUM_LABELS)]
    ))
    
    # Save results
    results = {
        'test_accuracy': float(np.mean(preds == y_test)),
        'classification_report': classification_report(
            y_test, preds,
            target_names=[ID2LABEL[i] for i in range(NUM_LABELS)],
            output_dict=True
        )
    }
    
    with open(OUTPUT_DIR / 'training_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nModel saved to: {OUTPUT_DIR}")
    print(f"Test Accuracy: {results['test_accuracy']:.4f}")
    print("\nTraining complete!")


if __name__ == '__main__':
    train()
