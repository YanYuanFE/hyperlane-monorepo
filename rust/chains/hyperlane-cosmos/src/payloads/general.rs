use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct EmptyStruct {}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Log {
    pub msg_index: u64,
    pub events: Vec<Event>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Event {
    #[serde(rename = "type")]
    pub typ: String,
    pub attributes: Vec<EventAttribute>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct EventAttribute {
    pub key: String,
    pub value: Option<String>,
    pub index: bool,
}
