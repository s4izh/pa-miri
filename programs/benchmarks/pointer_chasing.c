struct Node {
    struct Node* next;
    int val;
};

#define LIST_SIZE 16

int main() {
    struct Node nodes[LIST_SIZE];
    for(int i = 0; i < LIST_SIZE-1; i++) {
        nodes[i].next = &nodes[i+1];
        nodes[i].val = i;
    }
    nodes[LIST_SIZE-1].next = 0;

    // chase pointers
    // every load depends on the previous load hit
    struct Node* curr = &nodes[0];
    int sum = 0;
    while(curr != 0) {
        sum += curr->val;
        curr = curr->next;
    }

    return 0;
}
