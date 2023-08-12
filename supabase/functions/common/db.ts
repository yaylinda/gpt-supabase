export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      admin_settings: {
        Row: {
          initial_chat_credits: number
          initial_message_credits: number
        }
        Insert: {
          initial_chat_credits?: number
          initial_message_credits?: number
        }
        Update: {
          initial_chat_credits?: number
          initial_message_credits?: number
        }
        Relationships: []
      }
      chat_members: {
        Row: {
          chat_id: string
          user_id: string
        }
        Insert: {
          chat_id: string
          user_id: string
        }
        Update: {
          chat_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_members_chat_id_fkey"
            columns: ["chat_id"]
            referencedRelation: "chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_members_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      chat_messages: {
        Row: {
          chat_id: string
          completion_tokens: number
          content: string
          embedding: string | null
          id: string
          prompt_tokens: number
          response_to_sender_id: string | null
          role: string
          sender_id: string | null
          timestamp: string
          total_tokens: number
        }
        Insert: {
          chat_id: string
          completion_tokens?: number
          content: string
          embedding?: string | null
          id?: string
          prompt_tokens?: number
          response_to_sender_id?: string | null
          role: string
          sender_id?: string | null
          timestamp?: string
          total_tokens?: number
        }
        Update: {
          chat_id?: string
          completion_tokens?: number
          content?: string
          embedding?: string | null
          id?: string
          prompt_tokens?: number
          response_to_sender_id?: string | null
          role?: string
          sender_id?: string | null
          timestamp?: string
          total_tokens?: number
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_chat_id_fkey"
            columns: ["chat_id"]
            referencedRelation: "chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_sender_id_fkey"
            columns: ["sender_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      chats: {
        Row: {
          ai_name: string
          created_at: string
          created_by: string
          gpt_chat_model: string
          gpt_embed_model: string
          id: string
          initial_message_credits: number
          last_message: Json | null
          members: string[] | null
          name: string
          num_message_credits_total: number
          num_message_credits_used: number
          num_tokens_used: number
          prompt_message_content: string
          updated_at: string
        }
        Insert: {
          ai_name: string
          created_at?: string
          created_by: string
          gpt_chat_model: string
          gpt_embed_model: string
          id?: string
          initial_message_credits?: number
          last_message?: Json | null
          members?: string[] | null
          name: string
          num_message_credits_total?: number
          num_message_credits_used?: number
          num_tokens_used?: number
          prompt_message_content?: string
          updated_at?: string
        }
        Update: {
          ai_name?: string
          created_at?: string
          created_by?: string
          gpt_chat_model?: string
          gpt_embed_model?: string
          id?: string
          initial_message_credits?: number
          last_message?: Json | null
          members?: string[] | null
          name?: string
          num_message_credits_total?: number
          num_message_credits_used?: number
          num_tokens_used?: number
          prompt_message_content?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "chats_created_by_fkey"
            columns: ["created_by"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      friends: {
        Row: {
          friend_pair: string
          request_accepted: boolean | null
          requested_on: string
          requestee: string
          requester: string
          responded_on: string | null
        }
        Insert: {
          friend_pair: string
          request_accepted?: boolean | null
          requested_on?: string
          requestee: string
          requester: string
          responded_on?: string | null
        }
        Update: {
          friend_pair?: string
          request_accepted?: boolean | null
          requested_on?: string
          requestee?: string
          requester?: string
          responded_on?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "friends_requestee_fkey"
            columns: ["requestee"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friends_requester_fkey"
            columns: ["requester"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      game_actions: {
        Row: {
          action: string
          created_at: string
          game_id: string
          id: string
          metadata: Json
          user_id: string
        }
        Insert: {
          action: string
          created_at?: string
          game_id: string
          id?: string
          metadata: Json
          user_id: string
        }
        Update: {
          action?: string
          created_at?: string
          game_id?: string
          id?: string
          metadata?: Json
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_actions_game_id_fkey"
            columns: ["game_id"]
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_actions_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          }
        ]
      }
      game_participants: {
        Row: {
          game_id: string
          status: string
          user_id: string
        }
        Insert: {
          game_id: string
          status: string
          user_id: string
        }
        Update: {
          game_id?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_participants_game_id_fkey"
            columns: ["game_id"]
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_participants_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          }
        ]
      }
      games: {
        Row: {
          created_at: string
          created_by: string
          id: string
          is_multiplayer: boolean
          metadata: Json
          name: string
          participants: string[]
          status: string
          type: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          is_multiplayer?: boolean
          metadata: Json
          name: string
          participants?: string[]
          status: string
          type: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          is_multiplayer?: boolean
          metadata?: Json
          name?: string
          participants?: string[]
          status?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "games_created_by_fkey"
            columns: ["created_by"]
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          }
        ]
      }
      profiles: {
        Row: {
          created_at: string
          discriminator: string
          email: string
          id: string
          initial_message_credits: number
          num_chat_credits_total: number
          num_chat_credits_used: number
          num_friends: number
          platform: string | null
          username: string
        }
        Insert: {
          created_at?: string
          discriminator?: string
          email?: string
          id: string
          initial_message_credits?: number
          num_chat_credits_total?: number
          num_chat_credits_used?: number
          num_friends?: number
          platform?: string | null
          username: string
        }
        Update: {
          created_at?: string
          discriminator?: string
          email?: string
          id?: string
          initial_message_credits?: number
          num_chat_credits_total?: number
          num_chat_credits_used?: number
          num_friends?: number
          platform?: string | null
          username?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_id_fkey"
            columns: ["id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      purchases: {
        Row: {
          applied: boolean
          chat_id: string | null
          customer_info: Json | null
          id: string
          num_credits: number
          platform: string
          product: Json | null
          timestamp: string
          type: string
          user_id: string
        }
        Insert: {
          applied?: boolean
          chat_id?: string | null
          customer_info?: Json | null
          id?: string
          num_credits: number
          platform: string
          product?: Json | null
          timestamp?: string
          type: string
          user_id: string
        }
        Update: {
          applied?: boolean
          chat_id?: string | null
          customer_info?: Json | null
          id?: string
          num_credits?: number
          platform?: string
          product?: Json | null
          timestamp?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchases_chat_id_fkey"
            columns: ["chat_id"]
            referencedRelation: "chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchases_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          }
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      ivfflathandler: {
        Args: {
          "": unknown
        }
        Returns: unknown
      }
      search_messages: {
        Args: {
          chat_id: string
          query_embedding: string
          similarity_threshold: number
          max_rows: number
          exclude_id: string
        }
        Returns: {
          chat_id: string
          completion_tokens: number
          content: string
          embedding: string | null
          id: string
          prompt_tokens: number
          response_to_sender_id: string | null
          role: string
          sender_id: string | null
          timestamp: string
          total_tokens: number
        }[]
      }
      vector_avg: {
        Args: {
          "": number[]
        }
        Returns: string
      }
      vector_dims: {
        Args: {
          "": string
        }
        Returns: number
      }
      vector_norm: {
        Args: {
          "": string
        }
        Returns: number
      }
      vector_out: {
        Args: {
          "": string
        }
        Returns: unknown
      }
      vector_send: {
        Args: {
          "": string
        }
        Returns: string
      }
      vector_typmod_in: {
        Args: {
          "": unknown[]
        }
        Returns: number
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

