//
//  ContentView.swift
//  PhoneAuth
//
//  Created by Tariq Almazyad on 18/06/2022.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State var isShowingHomeView: Bool = false
    @State var phoneNumber: String = ""
    @State var smsCode: String = ""
    @StateObject var authManager = AuthManager()
    var body: some View {
        NavigationView{
            VStack{
                SecureField("Enter Phone Number", text: $phoneNumber)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white, lineWidth: 0.5)
                    )
                    .padding()
                Button {
                    
                    authManager.createUserWithPhoneNumber(phoneNumber: phoneNumber) { isSuccess in
                        print("DEBUG: phone \(isSuccess)")
                    }
                    
                } label: {
                    Text("Create Account")
                }
                
                Divider()
                
                TextField("Enter OPT Code", text: $smsCode)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white, lineWidth: 0.5)
                    )
                    .padding()
                
                
                Button {
                    DispatchQueue.main.async {
                        authManager.verifySMSCode(verificationCode: smsCode, phoneNumber: phoneNumber) { isSuccess in
                            print("DEBUG: in code \(isSuccess)")
                            isShowingHomeView.toggle()
                        }
                    }
                } label: {
                    Text("Verify Code")
                }
                
                
            }
            .navigationTitle("Phone Auth")
        }.fullScreenCover(isPresented: $isShowingHomeView) {
            Text("You are Good to go 😎")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}

struct User: Codable {
    let id: String
    let name: String
    let phoneNumber: String
}


class AuthManager: ObservableObject {
    @Published var verificationId: String?
    private let auth = Auth.auth()
    
    func createUserWithPhoneNumber(phoneNumber: String, completion: @escaping ( (Bool) -> Void )) {
        print("DEBUG: 1 - preparing to request SMS Code")
        PhoneAuthProvider.provider().verifyPhoneNumber("+966" + phoneNumber, uiDelegate: nil) { [weak self] verificationId, error in
            print("DEBUG: 2 - Sending Request")
            if let error = error {
                print("DEBUG: error while getting verificationId \(error)")
            }
            guard let verificationId = verificationId else {
                completion(false)
                return
            }
            print("DEBUG: 3 - Successfully requested SMS Code")
            self?.verificationId = verificationId
            completion(true)
        }
    }
    
    func verifySMSCode(verificationCode: String, phoneNumber: String , completion: @escaping ( (Bool) -> Void )) {
        print("DEBUG: 4 - Verifying SMS Code")
        guard let verificationId = verificationId else {
            completion(false)
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationId,
                                                                 verificationCode: verificationCode)
        print("DEBUG: 5 - Create Credential")
        auth.signIn(with: credential) { authResult, error in
            if let error = error {
                print("DEBUG: error while verifying smsCode \(error)")
            }
            print("DEBUG: 6 - Successfully Uploaded user info to firebase with saved phone number")
            guard let authResult = authResult else {return}
            let userId = authResult.user.uid
            let userData = [
                "id": userId,
                "phoneNumber": phoneNumber
            ]
            
            Firestore.firestore().collection("users").document(userId).setData(userData)
            completion(true)
        }
    }
}
